/*
 * WebCertificateRenewController.swift
 * officectl
 *
 * Created by François Lamboley on 2019/05/23.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ASN1Decoder
import CollectionConcurrencyKit
import Email
import GenericJSON
import OfficeKit
import UnwrapOrThrow
import URLRequestOperation
import Vapor



class WebCertificateRenewController {
	
	func showLogin(_ req: Request) async throws -> View {
		struct CertifRenewContext : Encodable {
			var isAdmin: Bool
			var userEmail: String
		}
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let email = try loggedInUser.user.hop(to: emailService).user.userID
		return try await req.view.render("CertificateRenewHome", CertifRenewContext(isAdmin: loggedInUser.scopes.contains(.admin), userEmail: email.rawValue))
	}
	
	func renewCertificate(_ req: Request) async throws -> Response {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		let certRenewData = try req.content.decode(VaultCertRenewData.self)
		let renewedCommonName = certRenewData.userEmail.localPart
		
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let loggedInEmail = try loggedInUser.user.hop(to: emailService).user.userID
		
		guard loggedInUser.scopes.contains(.admin) || loggedInEmail == certRenewData.userEmail else {
			throw Abort(.forbidden, reason: "Non-admin users can only get a certificate for themselves.")
		}
		
		let officectlConfig = req.application.officectlConfig
		let vaultBaseURL = try officectlConfig.tmpVaultBaseURL?.appendingPathComponent("v1") ?! MissingFieldError("tmpVaultBaseURL")
		let issuerName = try officectlConfig.tmpVaultIssuerName ?! MissingFieldError("tmpVaultIssuerName")
		let additionalActiveIssuers = officectlConfig.tmpVaultAdditionalActiveIssuers ?? []
		let additionalPassiveIssuers = officectlConfig.tmpVaultAdditionalPassiveIssuers ?? []
		let additionalCertificates = officectlConfig.tmpVaultAdditionalCertificates ?? []
		let token = try officectlConfig.tmpVaultToken ?! MissingFieldError("tmpVaultToken")
		let ttl = try officectlConfig.tmpVaultTTL ?! MissingFieldError("tmpVaultTTL")
		let expirationLeeway = try officectlConfig.tmpVaultExpirationLeeway ?! MissingFieldError("tmpVaultExpirationLeeway")
		let expectedExpiration = Date() + expirationLeeway
		
		@Sendable
		func authenticate(_ request: URLRequest) -> URLRequest {
			var request = request
			request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
			return request
		}
		
		let certificatesToRevoke = try await ([issuerName] + additionalActiveIssuers).concurrentFlatMap{ issuerName -> [Certificate] in
			return try await Certificate.getAll(
				from: issuerName,
				includeRevoked: false,
				vaultBaseURL: vaultBaseURL,
				vaultAuthenticator: AuthRequestProcessor(authHandler: authenticate)
			)
		}.filter{ $0.commonName == renewedCommonName }
		
		/* We check if all of the certificates to revoke will expire in less than n seconds (where n is defined in the conf).
		 * If the user is admin we don’t do this check (admin can renew any certif they want whenever they want). */
		if !loggedInUser.scopes.contains(.admin) {
			try certificatesToRevoke.forEach{ idAndCertif in
				let certif = idAndCertif.certif
				guard !certif.checkValidity(expectedExpiration) else {
					throw InvalidArgumentError(message: "You’ve got at least one certificate still valid, please use it or see an ops!")
				}
			}
		}
		
		/* Revoke the certificates to revoke */
		try req.application.auditLogger.log(action: "Revoking \(certificatesToRevoke.count) certificate(s): \(certificatesToRevoke.map{ $0.issuerName + ":" + $0.id }.joined(separator: " ")).", source: .web)
		try await certificatesToRevoke.concurrentForEach{ certificateToRevoke in
			let (id, issuerName) = (certificateToRevoke.id, certificateToRevoke.issuerName)
			let op = try URLRequestDataOperation<VaultResponse<VaultRevocationResult?>>.forAPIRequest(
				url: vaultBaseURL.appending(issuerName, "revoke"), httpBody: ["serial_number": id],
				requestProcessors: [AuthRequestProcessor(authHandler: authenticate)],
				resultProcessorModifier: { rp in
					rp.flatMapError{ (error, response) in
						/* Vault returns an empty reply if revoking an expired certificate,
						 * so we erase the error in case we get an empty reply from the Vault API. */
						if (response as? HTTPURLResponse)?.statusCode == 204 {
							return VaultResponse(data: nil)
						}
						throw error
					}
				}, retryProviders: []
			)
			_ = try await op.startAndGetResult()
		}
		
		/* Create the new certificate */
		try req.application.auditLogger.log(action: "Creating certificate w/ CN \(renewedCommonName).", source: .web)
		let opCreateCertif = try URLRequestDataOperation<VaultResponse<VaultNewCertificate>>.forAPIRequest(
			url: vaultBaseURL.appending(issuerName, "issue", "client"), httpBody: ["common_name": renewedCommonName, "ttl": ttl],
			requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
		)
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		var newCertificate = try await opCreateCertif.startAndGetResult().result.data
		
		/* We recreate the CA chain because we can have more than one, and because vault does not add the root CA anyway… */
		newCertificate.caChain.removeAll()
		try await withThrowingTaskGroup(of: VaultCertificateContainer.self, returning: Void.self, body: { group in
			/* Let’s retrieve CAs */
			for issuerName in ([issuerName] + additionalActiveIssuers + additionalPassiveIssuers) {
				group.addTask{
					let op = URLRequestDataOperation<VaultResponse<VaultCertificateContainer>>.forAPIRequest(
						url: try vaultBaseURL.appending(issuerName, "cert", "ca"),
						requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
					)
					return try await op.startAndGetResult().result.data
				}
			}
			/* Let’s retrieve additional certificates */
			for additionalCertificate in additionalCertificates {
				group.addTask{
					let op = URLRequestDataOperation<VaultResponse<VaultCertificateContainer>>.forAPIRequest(
						url: try vaultBaseURL.appending(additionalCertificate.issuer, "cert", additionalCertificate.id),
						requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
					)
					return try await op.startAndGetResult().result.data
				}
			}
			
			while let currentChainCertificate = try await group.next() {
				newCertificate.caChain.append(currentChainCertificate.pem)
			}
		})
		
		let randomID = UUID().uuidString
		let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(randomID, isDirectory: true)
		
		let caURL = URL(fileURLWithPath: "ca.pem", relativeTo: baseURL)
		let keyURL = URL(fileURLWithPath: renewedCommonName + ".key", relativeTo: baseURL)
		let certifURL = URL(fileURLWithPath: renewedCommonName + ".pem", relativeTo: baseURL)
		
		var failure: Error?
		let opWriteCertif = BlockOperation{
			do {
				try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
				let keyData = Data(newCertificate.privateKey.utf8)
				let certifData = Data(newCertificate.certificate.utf8)
				let caData = Data(Set(newCertificate.caChain).joined(separator: "\n").utf8)
				
				try caData.write(to: caURL)
				try keyData.write(to: keyURL)
				try certifData.write(to: certifURL)
			} catch {
				failure = error
			}
		}
		
		let tarURL = baseURL.appendingPathComponent(randomID).appendingPathExtension("tar.bz2")
		let tarOp = TarOperation(sources: [keyURL.relativePath, certifURL.relativePath, caURL.relativePath], relativeTo: baseURL, destination: tarURL, compress: true, deleteSourcesOnSuccess: true)
		tarOp.addDependency(opWriteCertif)
		
		defaultOperationQueueForFutureSupport.addOperation(opWriteCertif)
		await defaultOperationQueueForFutureSupport.addOperationAndWait(tarOp)
		if let error = failure {throw error}
		
		let certificateFileName = "certificates_happn_\(renewedCommonName)"
		let res = req.fileio.streamFile(at: tarURL.path)
		res.headers.contentType = .binary
		res.headers.contentDisposition = .init(.attachment, name: certificateFileName, filename: certificateFileName + ".tar.bz2")
		return res
	}
	
}
