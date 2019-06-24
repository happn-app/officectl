/*
 * WebCertificateRenewController.swift
 * officectl
 *
 * Created by François Lamboley on 23/05/2019.
 */

import Foundation

import OfficeKit
import Vapor

import COpenSSL
import GenericJSON



class WebCertificateRenewController {
	
	func showLogin(_ req: Request) throws -> Future<View> {
		return try req.view().render("CertificateRenewLogin")
	}
	
	func renewCertificate(_ req: Request) throws -> Future<Response> {
		let renewCertificateData = try req.content.syncDecode(RenewCertificateData.self)
		let renewedCommonName = renewCertificateData.email.username
		
		let asyncConfig = try req.make(AsyncConfig.self)
		let officectlConfig = try req.make(OfficectlConfig.self)
		let officeKitConfig = try req.make(OfficeKitConfig.self)
		let basePeopleDN = try nil2throw(officeKitConfig.ldapConfigOrThrow().peopleBaseDNPerDomain?[officeKitConfig.mainDomain(for: renewCertificateData.email.domain)], "LDAP People Base DN")
		let user = User(email: renewCertificateData.email, basePeopleDN: basePeopleDN, setMainIdToLDAP: true)
		
		let baseURL = try nil2throw(officectlConfig.tmpVaultBaseURL).appendingPathComponent("v1")
		let issuerName = try nil2throw(officectlConfig.tmpVaultIssuerName)
		let token = try nil2throw(officectlConfig.tmpVaultToken)
		let ttl = try nil2throw(officectlConfig.tmpVaultTTL)
		
		func authenticate(_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void {
			var request = request
			request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
			handler(.success(request), nil)
		}
		
		return try user
		.checkLDAPPassword(container: req, checkedPassword: renewCertificateData.password)
		.then{ _ -> Future<CertificateSerialsList> in
			/* Now the user is authenticated, let’s fetch the list of current
			 * certificates in the vault */
			var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("certs"))
			urlRequest.httpMethod = "LIST"
			let op = AuthenticatedJSONOperation<VaultResponse<CertificateSerialsList>>(request: urlRequest, authenticator: authenticate)
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue).map{ $0.data }
		}
		.then{ certificatesList -> Future<[String?]> in
			/* Get the list of certificates to revoke */
			let futures = certificatesList.keys.map{ id -> Future<String?> in
				let urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("cert").appendingPathComponent(id))
				let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
				return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue).map{ certificateResponse in
					guard certificateResponse.data.certificate.commonName == renewedCommonName else {return nil}
					return id
				}
			}
			return Future.reduce([String?](), futures, eventLoop: asyncConfig.eventLoop, { full, new in
				return full + [new]
			})
		}
		.then{ certificateIdsToRevoke -> Future<Void> in
			/* Revoke the certificates to revoke */
			let futures = certificateIdsToRevoke.compactMap{ $0 }.map{ id -> Future<Void> in
				var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("revoke"))
				urlRequest.httpMethod = "POST"
				let json = JSON(dictionaryLiteral: ("serial_number", JSON(stringLiteral: id)))
				urlRequest.httpBody = try! JSONEncoder().encode(json)
				let op = AuthenticatedJSONOperation<VaultResponse<RevocationResult>>(request: urlRequest, authenticator: authenticate)
				return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue).map{ _ in return () }
			}
			return Future.reduce((), futures, eventLoop: asyncConfig.eventLoop, { _, _ in () })
		}
		.then{ _ -> Future<NewCertificate> in
			/* Create the new certificate */
			var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("issue").appendingPathComponent("client"))
			urlRequest.httpMethod = "POST"
			let json = JSON(dictionaryLiteral: ("common_name", JSON(stringLiteral: renewedCommonName)), ("ttl", JSON(stringLiteral: ttl)))
			urlRequest.httpBody = try! JSONEncoder().encode(json)
			let op = AuthenticatedJSONOperation<VaultResponse<NewCertificate>>(request: urlRequest, authenticator: authenticate)
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue).map{ $0.data }
		}
		.then{ newCertificate -> Future<URL> in
			let randomId = UUID().uuidString
			let baseName = renewedCommonName + "_" + randomId
			let baseURL = FileManager.default.temporaryDirectory
			
			let keyURL = baseURL.appendingPathComponent(baseName).appendingPathExtension("key")
			let certifURL = baseURL.appendingPathComponent(baseName).appendingPathExtension("pem")
			let caURL = baseURL.appendingPathComponent("ca_" + randomId).appendingPathExtension("pem")
			
			var failure: Error?
			let op = BlockOperation{
				do {
					let caData = Data(newCertificate.issuingCa.utf8)
					let keyData = Data(newCertificate.privateKey.utf8)
					let certifData = Data(newCertificate.certificate.utf8)
					
					try caData.write(to: caURL)
					try keyData.write(to: keyURL)
					try certifData.write(to: certifURL)
				} catch {
					failure = error
				}
			}
			
			let tarURL = baseURL.appendingPathComponent(randomId).appendingPathExtension("tar.bz2")
			let tarOp = TarOperation(sources: [keyURL.path, certifURL.path, caURL.path], relativeTo: baseURL, destination: tarURL, compress: true, deleteSourcesOnSuccess: true)
			tarOp.addDependency(op)
			
			asyncConfig.operationQueue.addOperation(op)
			return asyncConfig.eventLoop.future(from: tarOp, queue: asyncConfig.operationQueue, resultRetriever: { _ in if let error = failure {throw error}; return tarURL })
		}
		.flatMap(to: Data.self, { url in
			let fileio = try req.fileio()
			return fileio.read(file: url.path)
		})
		.map{ data in
			return req.response(data, as: .tar)
		}
	}
	
	private struct RenewCertificateData : Decodable {
		
		var email: Email
		var password: String
		
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
		
		/* We only need the common name. */
		var commonName: String
		
		init(pemData: LosslessDataConvertible) throws {
			let bio = BIO_new(BIO_s_mem())
			defer {BIO_free(bio)}
			
			let nullTerminatedData = pemData.convertToData() + Data([0])
			_ = nullTerminatedData.withUnsafeBytes{ (key: UnsafeRawBufferPointer) -> Int32 in
				let key = key.bindMemory(to: Int8.self).baseAddress!
				return BIO_puts(bio, key)
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
			commonName = String(cString: ASN1_STRING_data(commonNameASN1))
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			try self.init(pemData: container.decode(String.self))
		}
		
	}
	
}
