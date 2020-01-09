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

import OfficeKit
import URLRequestOperation
import Vapor

import COpenSSL
import GenericJSON



class WebCertificateRenewController {
	
	func showLogin(_ req: Request) throws -> EventLoopFuture<View> {
		return req.view.render("CertificateRenewLogin")
	}
	
	func renewCertificate(_ req: Request) throws -> EventLoopFuture<Response> {
		let renewCertificateData = try req.content.decode(RenewCertificateData.self)
		let renewedCommonName = renewCertificateData.email.username
		
		let officeKitServiceProvider = req.application.officeKitServiceProvider
		let authService = try officeKitServiceProvider.getDirectoryAuthenticatorService()
		let user = try authService.logicalUser(fromEmail: renewCertificateData.email, servicesProvider: officeKitServiceProvider)
		
		let officectlConfig = req.application.officectlConfig
		let baseURL = try nil2throw(officectlConfig.tmpVaultBaseURL).appendingPathComponent("v1")
		let rootCAName = try nil2throw(officectlConfig.tmpVaultRootCAName)
		let issuerName = try nil2throw(officectlConfig.tmpVaultIssuerName)
		let token = try nil2throw(officectlConfig.tmpVaultToken)
		let ttl = try nil2throw(officectlConfig.tmpVaultTTL)
		
		func authenticate(_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void {
			var request = request
			request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
			handler(.success(request), nil)
		}
		
		return try authService.authenticate(userId: user.userId, challenge: renewCertificateData.password, using: req.services)
		.flatMapThrowing{ authSuccess -> Void in
			guard authSuccess else {throw InvalidArgumentError(message: "Cannot login with these credentials.")}
		}
		.flatMapThrowing{ _ -> EventLoopFuture<CertificateSerialsList> in
			/* Now the user is authenticated, let’s fetch the list of current
			 * certificates in the vault */
			var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("certs"))
			urlRequest.httpMethod = "LIST"
			let op = AuthenticatedJSONOperation<VaultResponse<CertificateSerialsList>>(request: urlRequest, authenticator: authenticate)
			return EventLoopFuture<VaultResponse<CertificateSerialsList>>.future(from: op, on: req.eventLoop).map{ $0.data }
		}
		.flatMap{ $0 }
		.flatMap{ certificatesList -> EventLoopFuture<[String]> in
			/* Get the list of certificates to revoke */
			let futures = certificatesList.keys.map{ id -> EventLoopFuture<String?> in
				let urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("cert").appendingPathComponent(id))
				let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
				return EventLoopFuture<VaultResponse<CertificateContainer>>.future(from: op, on: req.eventLoop).map{ certificateResponse in
					guard certificateResponse.data.certificate.commonName == renewedCommonName else {return nil}
					return id
				}
			}
			return EventLoopFuture.reduce([String](), futures, on: req.eventLoop, { full, new in
				guard let new = new else {return full}
				return full + [new]
			})
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
			return req.fileio.streamFile(at: url.path)
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
		
		init(pem p: String) throws {
			let bio = BIO_new(BIO_s_mem())
			defer {BIO_free(bio)}
			
			let nullTerminatedData = Data(p.utf8) + Data([0])
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
			pem = p
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			try self.init(pem: container.decode(String.self))
		}
		
	}
	
}
