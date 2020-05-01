/*
 * WebCertificateRenewController.swift
 * officectl
 *
 * Created by François Lamboley on 23/05/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import GenericJSON
import OfficeKit
import URLRequestOperation
import Vapor

import COpenSSL



class WebCertificateRenewController {
	
	func showLogin(_ req: Request) throws -> EventLoopFuture<View> {
		struct CertifRenewContext : Encodable {
			var isAdmin: Bool
			var userEmail: String
		}
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let email = try loggedInUser.user.hop(to: emailService).user.userId
		return req.view.render("CertificateRenewHome", CertifRenewContext(isAdmin: loggedInUser.isAdmin, userEmail: email.stringValue))
	}
	
	func renewCertificate(_ req: Request) throws -> EventLoopFuture<Response> {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		let certRenewData = try req.content.decode(CertRenewData.self)
		let renewedCommonName = certRenewData.userEmail.username
		
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let loggedInEmail = try loggedInUser.user.hop(to: emailService).user.userId
		
		guard loggedInUser.isAdmin || loggedInEmail == certRenewData.userEmail else {
			throw Abort(.forbidden, reason: "Non-admin users can only get a certificate for themselves.")
		}
		
		let officectlConfig = req.application.officectlConfig
		let baseURL = try nil2throw(officectlConfig.tmpVaultBaseURL).appendingPathComponent("v1")
		let rootCAName = try nil2throw(officectlConfig.tmpVaultRootCAName)
		let issuerName = try nil2throw(officectlConfig.tmpVaultIssuerName)
		let token = try nil2throw(officectlConfig.tmpVaultToken)
		let ttl = try nil2throw(officectlConfig.tmpVaultTTL)
		let expirationLeeway = try nil2throw(officectlConfig.tmpVaultExpirationLeeway)
		let expectedExpiration = Date(timeIntervalSinceNow: -expirationLeeway)
		
		func authenticateSync(_ request: inout URLRequest) -> Void {
			request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
		}
		
		func authenticate(_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void {
			var request = request
			authenticateSync(&request)
			handler(.success(request), nil)
		}
		
		return req.eventLoop.future()
		.flatMap{ _ -> EventLoopFuture<CRL> in
			/* Let’s get the CRL */
			var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("crl"))
			authenticateSync(&urlRequest)
			let op = URLRequestOperation(request: urlRequest)
			return EventLoopFuture<CRL>.future(from: op, on: req.eventLoop, resultRetriever: { op in
				guard let data = op.fetchedData else {
					throw op.finalError ?? NSError(domain: "com.happn.officeclt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error fetching the CRL"])
				}
				return try CRL(der: data)
			})
		}
		.flatMapThrowing{ crl -> EventLoopFuture<(CertificateSerialsList, CRL)> in
			/* Let’s fetch the list of current certificates in the vault */
			var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("certs"))
			urlRequest.httpMethod = "LIST"
			let op = AuthenticatedJSONOperation<VaultResponse<CertificateSerialsList>>(request: urlRequest, authenticator: authenticate)
			return EventLoopFuture<VaultResponse<CertificateSerialsList>>.future(from: op, on: req.eventLoop).map{ ($0.data, crl) }
		}
		.flatMap{ $0 }
		.flatMap{ (certificatesList, crl) -> EventLoopFuture<[(id: String, certif: Certificate)]> in
			/* Get the list of certificates to revoke */
			let futures = certificatesList.keys.compactMap{ id -> EventLoopFuture<(id: String, certif: Certificate)?>? in
				/* If the certificate is already revoked, we don’t have to do
				 * anything w/ it. */
				guard !crl.revokedCertificateIds.contains(normalizeCertificateId(id)) else {
					return nil
				}
				
				let urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("cert").appendingPathComponent(id))
				let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
				return EventLoopFuture<VaultResponse<CertificateContainer>>.future(from: op, on: req.eventLoop).map{ certificateResponse in
					guard certificateResponse.data.certificate.commonName == renewedCommonName else {return nil}
					return (id: id, certif: certificateResponse.data.certificate)
				}
			}
			return EventLoopFuture.reduce([(id: String, certif: Certificate)](), futures, on: req.eventLoop, { full, new in
				guard let new = new else {return full}
				return full + [new]
			})
		}
		.flatMapThrowing{ certificatesToRevoke -> [String] in
			/* We check if all of the certificates to revoke will expire in less
			 * than n seconds (where n is defined in the conf). If the user is
			 * admin we don’t do this check (admin can renew any certif they want
			 * whenever they want). */
			if !loggedInUser.isAdmin {
				try certificatesToRevoke.forEach{ idAndCertif in
					let certif = idAndCertif.certif
					guard certif.expirationDate < expectedExpiration else {
						throw InvalidArgumentError(message: "You’ve got at least one certificate still valid, please use it or see an ops!")
					}
				}
			}
			return certificatesToRevoke.map{ $0.id }
		}
		.flatMapThrowing{ certificateIdsToRevoke -> EventLoopFuture<Void> in
			/* Revoke the certificates to revoke */
			try req.application.auditLogger.log(action: "Revoking \(certificateIdsToRevoke.count) certificate(s): \(certificateIdsToRevoke.joined(separator: " ")).", source: .web)
			let futures = certificateIdsToRevoke.map{ id -> EventLoopFuture<Void> in
				var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("revoke"))
				urlRequest.httpMethod = "POST"
				let json = JSON(dictionaryLiteral: ("serial_number", JSON(stringLiteral: id)))
				urlRequest.httpBody = try! JSONEncoder().encode(json)
				let op = AuthenticatedJSONOperation<VaultResponse<RevocationResult>>(request: urlRequest, authenticator: authenticate)
				return EventLoopFuture<VaultResponse<RevocationResult>>.future(from: op, on: req.eventLoop).map{ _ in return () }
			}
			return EventLoopFuture.reduce((), futures, on: req.eventLoop, { _, _ in () })
		}
		.flatMap{ $0 }
		.flatMapThrowing{ _ -> EventLoopFuture<NewCertificate> in
			/* Create the new certificate */
			try req.application.auditLogger.log(action: "Creating certificate w/ CN \(renewedCommonName).", source: .web)
			var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("issue").appendingPathComponent("client"))
			urlRequest.httpMethod = "POST"
			let json = JSON(dictionaryLiteral: ("common_name", JSON(stringLiteral: renewedCommonName)), ("ttl", JSON(stringLiteral: ttl)))
			urlRequest.httpBody = try! JSONEncoder().encode(json)
			let op = AuthenticatedJSONOperation<VaultResponse<NewCertificate>>(request: urlRequest, authenticator: authenticate)
			return EventLoopFuture<VaultResponse<NewCertificate>>.future(from: op, on: req.eventLoop).map{ $0.data }
		}
		.flatMap{ $0 }
		.flatMapThrowing{ newCertificate -> EventLoopFuture<NewCertificate> in
			/* We add the root CA in the CA chain Vault returns… */
			let urlRequest = URLRequest(url: baseURL.appendingPathComponent(rootCAName).appendingPathComponent("cert").appendingPathComponent("ca"))
			let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
			return EventLoopFuture<VaultResponse<NewCertificate>>.future(from: op, on: req.eventLoop).map{ certificateResponse in
				var newCertificate = newCertificate
				newCertificate.caChain.append(certificateResponse.data.certificate.pem)
				return newCertificate
			}
		}
		.flatMap{ $0 }
		.flatMap{ newCertificate -> EventLoopFuture<URL> in
			let randomId = UUID().uuidString
			let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(randomId, isDirectory: true)
			
			let caURL = URL(fileURLWithPath: "ca.pem", relativeTo: baseURL)
			let keyURL = URL(fileURLWithPath: renewedCommonName + ".key", relativeTo: baseURL)
			let certifURL = URL(fileURLWithPath: renewedCommonName + ".pem", relativeTo: baseURL)
			
			var failure: Error?
			let op = BlockOperation{
				do {
					try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
					let keyData = Data(newCertificate.privateKey.utf8)
					let certifData = Data(newCertificate.certificate.utf8)
					let caData = Data(newCertificate.caChain.joined(separator: "\n").utf8)
					
					try caData.write(to: caURL)
					try keyData.write(to: keyURL)
					try certifData.write(to: certifURL)
				} catch {
					failure = error
				}
			}
			
			let tarURL = baseURL.appendingPathComponent(randomId).appendingPathExtension("tar.bz2")
			let tarOp = TarOperation(sources: [keyURL.relativePath, certifURL.relativePath, caURL.relativePath], relativeTo: baseURL, destination: tarURL, compress: true, deleteSourcesOnSuccess: true)
			tarOp.addDependency(op)
			
			defaultOperationQueueForFutureSupport.addOperation(op)
			return EventLoopFuture<URL>.future(from: tarOp, on: req.eventLoop, queue: defaultOperationQueueForFutureSupport, resultRetriever: { _ in if let error = failure {throw error}; return tarURL })
		}
		.map{ url in
			let certificateFileName = "certificates_happn_\(renewedCommonName)"
			let res = req.fileio.streamFile(at: url.path)
			res.headers.contentType = .binary
			res.headers.contentDisposition = .init(.attachment, name: certificateFileName, filename: certificateFileName + ".tar.bz2")
			return res
		}
	}
	
	private struct CertRenewData : Decodable {
		
		var userEmail: Email
		
	}
	
	private struct VaultResponse<ObjectType : Decodable> : Decodable {
		
		var data: ObjectType
		
	}
	
	private struct RevocationResult : Decodable {
		
		var revocationTime: Int
		
	}
	
	private struct NewCertificate : Decodable {
		
		var certificate: String
		var issuingCa: String
		var caChain: [String]
		var privateKey: String
		
	}
	
	private struct CertificateSerialsList : Decodable {
		
		var keys: [String]
		
	}
	
	private struct CertificateContainer : Decodable {
		
		var certificate: Certificate
		
	}
	
	/* Thanks https://wiki.openssl.org/index.php/Hostname_validation */
	private struct Certificate : Decodable {
		
		let pem: String
		
		/* Computed from the pem. */
		let commonName: String
		let expirationDate: Date
		
		init(pem p: String) throws {
			let bio = BIO_new(BIO_s_mem())
			defer {BIO_free(bio)}
			
			let nullTerminatedData = Data(p.utf8) + Data([0])
			_ = nullTerminatedData.withUnsafeBytes{ (pemBytes: UnsafeRawBufferPointer) -> Int32 in
				let pemBytes = pemBytes.bindMemory(to: Int8.self).baseAddress!
				return BIO_puts(bio, pemBytes)
			}
			
			guard let x509 = PEM_read_bio_X509(bio, nil, nil, nil) else {
				throw InternalError(message: "cannot read certificate")
			}
			defer {X509_free(x509)}
			
			/* Find the position of the CN field in the Subject field of the
			 * certificate */
			let commonNameLoc = X509_NAME_get_index_by_NID(X509_get_subject_name(x509), NID_commonName, -1)
			guard commonNameLoc >= 0 else {
				throw InternalError(message: "cannot get index of CN field")
			}
			guard let commonNameEntry = X509_NAME_get_entry(X509_get_subject_name(x509), commonNameLoc) else {
				throw InternalError(message: "cannot get CN field")
			}
			guard let commonNameASN1 = X509_NAME_ENTRY_get_data(commonNameEntry) else {
				throw InternalError(message: "cannot convert CN field to ASN1 string")
			}
			commonName = String(cString: ASN1_STRING_get0_data(commonNameASN1))
			
			guard let notAfterASN1Ptr = X509_get0_notAfter(x509) else {
				throw InternalError(message: "cannot get notAfter date")
			}
			#if true
			var partialDiffDays: Int32 = 0
			var partialDiffSeconds: Int32 = 0
			ASN1_TIME_diff(&partialDiffDays, &partialDiffSeconds, nil /* Now */, notAfterASN1Ptr)
			
			let nSecondsInADay = 24 * 60 * 60
			let diffSeconds = Int(partialDiffSeconds) + Int(partialDiffDays)*nSecondsInADay
			expirationDate = Date(timeIntervalSinceNow: TimeInterval(diffSeconds))
			
			#else
			/* This variant is only available around libssl 1.1.1, which is not
			 * available out of the box on Debian Stretch. */
			var notAfterTM = tm()
			guard ASN1_TIME_to_tm(notAfterASN1Ptr, &notAfterTM) == 1 else {
				throw InternalError(message: "cannot convert notAfter ASN1 date to tm")
			}
			/* ASN1_TIME_to_tm returns a GMT time so we use timegm */
			let time = timegm(&notAfterTM)
			expirationDate = Date(timeIntervalSince1970: Double(time))
			#endif
			
			pem = p
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			try self.init(pem: container.decode(String.self))
		}
		
	}
	
	/* Thanks http://fm4dd.com/openssl/crldisplay.shtm */
	private struct CRL {
		
		let der: Data
		
		/* Computed from the pem. */
		let revokedCertificateIds: Set<String>
		
		init(der d: Data) throws {
			let bio = BIO_new(BIO_s_mem())
			defer {BIO_free(bio)}
			
			_ = d.withUnsafeBytes{ (derBytes: UnsafeRawBufferPointer) -> Int32 in
				BIO_write(bio, derBytes.baseAddress!, Int32(derBytes.count))
			}
			
			/* We probably could have done this to read the CRL in the PEM format. */
//			PEM_read_bio_X509_CRL(bio, nil, nil, nil)
			guard let crl = d2i_X509_CRL_bio(bio, nil) else {
				throw InternalError(message: "cannot read CRL")
			}
			defer {X509_CRL_free(crl)}
			
			guard let revokedList = X509_CRL_get_REVOKED(crl) else {
				throw InternalError(message: "cannot get revoked certificates from CRL")
			}
			
			var revokedIds = Set<String>()
			let nRevoked = sk_X509_REVOKED_num(revokedList)
			for i in 0..<nRevoked {
				guard let revoked = sk_X509_REVOKED_value(revokedList, i) else {
					/* Getting the value should never fail, so we bail completely if
					 * we have an error for a revoked certificate. */
					throw InternalError(message: "cannot get revoked certificate at index \(i) in CRL")
				}
				guard let serialNumber = X509_REVOKED_get0_serialNumber(revoked) else {
					throw InternalError(message: "cannot get serial number of revoked certificate at index \(i) in CRL")
				}
				guard let serialNumberBN = ASN1_INTEGER_to_BN(serialNumber, nil) else {
					throw InternalError(message: "cannot get serial number as big num of certificate at index \(i) in CRL")
				}
				guard let serialNumberHexCStr = BN_bn2hex(serialNumberBN) else {
					throw InternalError(message: "cannot get serial number as hex str of certificate at index \(i) in CRL")
				}
				/* Doc says to deallocate the serialNumberHexStr using OPENSSL_free
				 * but this function is not available in Swift (it is a #define, not
				 * an actual function). */
				defer {CRYPTO_free(serialNumberHexCStr, #file, #line)}
				
				let serialNumberNormalizedHexStr = normalizeCertificateId(String(cString: serialNumberHexCStr))
				revokedIds.insert(String(serialNumberNormalizedHexStr))
			}
			revokedCertificateIds = revokedIds
			
			der = d
		}
		
	}
	
}


private func normalizeCertificateId(_ id: String) -> String {
	let characterSet = CharacterSet(charactersIn: "0123456789abcdef")
	var preresult = id.lowercased().drop{ $0 == "0" }
	preresult.removeAll{
		let scalars = $0.unicodeScalars
		guard let scalar = scalars.onlyElement else {return true}
		return !characterSet.contains(scalar)
	}
	return String(preresult)
}
