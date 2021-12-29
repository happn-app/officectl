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
		let email = try loggedInUser.user.hop(to: emailService).user.userId
		return try await req.view.render("CertificateRenewHome", CertifRenewContext(isAdmin: loggedInUser.isAdmin, userEmail: email.rawValue))
	}
	
	func renewCertificate(_ req: Request) async throws -> Response {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		let certRenewData = try req.content.decode(CertRenewData.self)
		let renewedCommonName = certRenewData.userEmail.localPart
		
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let loggedInEmail = try loggedInUser.user.hop(to: emailService).user.userId
		
		guard loggedInUser.isAdmin || loggedInEmail == certRenewData.userEmail else {
			throw Abort(.forbidden, reason: "Non-admin users can only get a certificate for themselves.")
		}
		
		let officectlConfig = req.application.officectlConfig
		let vaultBaseURL = try nil2throw(officectlConfig.tmpVaultBaseURL).appendingPathComponent("v1")
		let issuerName = try nil2throw(officectlConfig.tmpVaultIssuerName)
		let additionalActiveIssuers = officectlConfig.tmpVaultAdditionalActiveIssuers ?? []
		let additionalPassiveIssuers = officectlConfig.tmpVaultAdditionalPassiveIssuers ?? []
		let additionalCertificates = officectlConfig.tmpVaultAdditionalCertificates ?? []
		let token = try nil2throw(officectlConfig.tmpVaultToken)
		let ttl = try nil2throw(officectlConfig.tmpVaultTTL)
		let expirationLeeway = try nil2throw(officectlConfig.tmpVaultExpirationLeeway)
		let expectedExpiration = Date() + expirationLeeway
		
		@Sendable
		func authenticate(_ request: URLRequest) -> URLRequest {
			var request = request
			request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
			return request
		}
		
		let certificatesToRevoke = try await ([issuerName] + additionalActiveIssuers).concurrentFlatMap{ issuerName -> [(id: String, issuerName: String, certif: X509Certificate)] in
			/* Let’s get the CRL */
			let opCRL = try URLRequestDataOperation.forData(url: vaultBaseURL.appending(issuerName, "crl"), requestProcessors: [AuthRequestProcessor(authHandler: authenticate)])
			let crl = try await CRL(der: opCRL.startAndGetResult().result)
			
			/* Let’s fetch the list of current certificates in the vault */
			let opListCurrentCertifs = URLRequestDataOperation<VaultResponse<CertificateSerialsList>>.forAPIRequest(
				url: try vaultBaseURL.appending(issuerName, "certs"), method: "LIST",
				errorType: VaultError.self, requestProcessors: [AuthRequestProcessor(authHandler: authenticate)],
				resultProcessorModifier: { rp in
					rp.flatMapError{ (error, response) in
						/* When there are no certificates in the PKI, vault returns a fucking 404!
						 * With a response like so '{"errors":[]}'. */
						if (response as? HTTPURLResponse)?.statusCode == 404,
							let e = error as? URLRequestOperationError.APIResultErrorWrapper<VaultError>,
							e.error.errors.isEmpty
						{
							return VaultResponse(data: CertificateSerialsList(keys: []))
						}
						throw error
					}
				}, retryProviders: []
			)
			let certificatesList = try await opListCurrentCertifs.startAndGetResult().result.data
			/* Note: An alternative to the flatMapError in the resultProcessorModifier in the operation above would be no modifier and catching the error.
			 * An example of implementation:
			 * 	let certificatesList: CertificateSerialsList
			 * 	do {
			 * 		certificatesList = try await opListCurrentCertifs.startAndGetResult().result.data
			 * 	} catch where URLRequestOperationError.APIResultErrorWrapper<VaultError>.get(from: error)?.error.errors.isEmpty ?? false {
			 * 		certificatesList = .init(keys: [])
			 * 	} */
			
			/* Get the list of certificates to revoke. */
			return try await certificatesList.keys.concurrentCompactMap{ id in
				guard !crl.revokedCertificateIds.contains(normalizeCertificateId(id)) else {
					/* If the certificate is already revoked, we don’t have to do anything w/ it. */
					return nil
				}
				let certificateResponse = try await URLRequestDataOperation<VaultResponse<CertificateContainer>>.forAPIRequest(
					url: try vaultBaseURL.appending(issuerName, "cert", id),
					requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
				).startAndGetResult().result
				guard let subjectDNStr = certificateResponse.data.certificate.subjectDistinguishedName else {
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get certificate CN for\n\(certificateResponse.data.pem)"])
				}
				let subjectDN = try LDAPDistinguishedName(string: subjectDNStr)
				guard let dnValue = subjectDN.values.onlyElement, dnValue.key == "CN" else {
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get certificate CN certificate DN \(subjectDN)"])
				}
				let subjectCN = dnValue.value
				guard subjectCN == renewedCommonName else {return nil}
				return (id: id, issuerName: issuerName, certif: certificateResponse.data.certificate)
			}
		}
		
		/* We check if all of the certificates to revoke will expire in less than n seconds (where n is defined in the conf).
		 * If the user is admin we don’t do this check (admin can renew any certif they want whenever they want). */
		if !loggedInUser.isAdmin {
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
			let (id, issuerName, _) = certificateToRevoke
			let op = try URLRequestDataOperation<VaultResponse<RevocationResult?>>.forAPIRequest(
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
		let opCreateCertif = try URLRequestDataOperation<VaultResponse<NewCertificate>>.forAPIRequest(
			url: vaultBaseURL.appending(issuerName, "issue", "client"), httpBody: ["common_name": renewedCommonName, "ttl": ttl],
			requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
		)
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		var newCertificate = try await opCreateCertif.startAndGetResult().result.data
		
		/* We recreate the CA chain because we can have more than one, and because vault does not add the root CA anyway… */
		newCertificate.caChain.removeAll()
		try await withThrowingTaskGroup(of: CertificateContainer.self, returning: Void.self, body: { group in
			/* Let’s retrieve CAs */
			for issuerName in ([issuerName] + additionalActiveIssuers + additionalPassiveIssuers) {
				group.addTask{
					let op = URLRequestDataOperation<VaultResponse<CertificateContainer>>.forAPIRequest(
						url: try vaultBaseURL.appending(issuerName, "cert", "ca"),
						requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
					)
					return try await op.startAndGetResult().result.data
				}
			}
			/* Let’s retrieve additional certificates */
			for additionalCertificate in additionalCertificates {
				group.addTask{
					let op = URLRequestDataOperation<VaultResponse<CertificateContainer>>.forAPIRequest(
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
		
		let randomId = UUID().uuidString
		let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(randomId, isDirectory: true)
		
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
		
		let tarURL = baseURL.appendingPathComponent(randomId).appendingPathExtension("tar.bz2")
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
	
	private struct CertRenewData : Decodable {
		
		var userEmail: Email
		
	}
	
	private struct VaultError : Decodable {
		
		var errors: [String] /* I guess this only ever contains strings, but doc is not explicit about it. */
		
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
		
		var pem: String
		var certificate: X509Certificate
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let pemStr = try container.decode(String.self, forKey: .certificate)
			certificate = try X509Certificate(pem: Data(pemStr.utf8))
			pem = pemStr
		}
		
		private enum CodingKeys : String, CodingKey {
			case certificate
		}
		
	}
	
	/* http://javadoc.iaik.tugraz.at/iaik_jce/current/iaik/x509/X509CRL.html
	 * https://tools.ietf.org/html/rfc5280 § 5.1 */
	private struct CRL {
		
		let der: Data
		
		/* Computed from the pem. */
		let revokedCertificateIds: Set<String>
		
		init(der d: Data) throws {
			let crlASN1Objects = try ASN1DERDecoder.decode(data: d)
			guard let crlASN1 = crlASN1Objects.onlyElement else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: got \(crlASN1Objects.count) objects, expected exactly 1."])
			}
			guard crlASN1.identifier?.tagNumber() == .sequence else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected SEQUENCE but got \(crlASN1)."])
			}
			
			/* We do not concern ourselves w/ the second and third objects of the sequence.
			 * They are resp. the signature algorithm used to sign the CRL and the signature.
			 * Yes, we do not verify the signature of the CRL.
			 * It’s bad but verification would be too complex to implement rn. */
			guard let tbsCertList = crlASN1.sub(0), tbsCertList.identifier?.tagNumber() == .sequence else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected SEQUENCE as first object of sequence got something else. CRL is \(crlASN1)"])
			}
			
			var delta = 0
			
			/* We only implement CRL v2 */
			guard let version = tbsCertList.sub(0 - delta), version.identifier?.tagNumber() == .integer, version.value as? Data == Data([1]) else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected INTEGER == 1 as first object of TBSCertList sequence, got something else. TBSCertList is \(tbsCertList)"])
			}
			
			/* We ignore values of the field 1, 2, 3 and 4, resp. signature, issuer, this update time and next update time.
			 * We will simply check the types of the fields (which will also allow skipping absent optional values). */
			guard let signature = tbsCertList.sub(1 - delta), signature.identifier?.tagNumber() == .sequence else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected SEQUENCE as second object of sequence, got something else. CRL is \(crlASN1)"])
			}
			guard let issuer = tbsCertList.sub(2 - delta), issuer.identifier?.tagNumber() == .sequence else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected SEQUENCE as third object of sequence, got something else. CRL is \(crlASN1)"])
			}
			guard let thisUpdate = tbsCertList.sub(3 - delta), thisUpdate.identifier?.tagNumber() == .utcTime || thisUpdate.identifier?.tagNumber() == .generalizedTime else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected UTC Time or GeneralizedTime as fourth object of sequence, got something else. CRL is \(crlASN1)"])
			}
			if let nextUpdate = tbsCertList.sub(4 - delta), nextUpdate.identifier?.tagNumber() == .utcTime || nextUpdate.identifier?.tagNumber() == .generalizedTime {
				/* We do nothing for now (or maybe ever tbh) */
			} else {
				delta += 1
			}
			
			var revokedIds = Set<String>()
			/* The revoked certificates list is optional */
			if let revokedCertificates = tbsCertList.sub(5 - delta), revokedCertificates.identifier?.tagNumber() == .sequence {
				let now = Date()
				for i in 0..<revokedCertificates.subCount() {
					guard let revokedCertificate = revokedCertificates.sub(i) else {
						throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: cannot get certificate at index \(i) inside the revoked certificates sequence. CRL is \(crlASN1)"])
					}
					guard revokedCertificate.identifier?.tagNumber() == .sequence else {
						if revokedCertificate.identifier?.tagNumber() != .endOfContent {
							throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected SEQUENCE or END_OF_CONTENT for certificate at index \(i) inside the revoked certificates sequence, got something else. CRL is \(crlASN1)"])
						} else {
							continue
						}
					}
					guard revokedCertificate.subCount() == 2 || revokedCertificate.subCount() == 3 else {
						throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: unexpected count of elements in a revoked certificate sequence. CRL is \(crlASN1)"])
					}
					guard
						let certificateSerialNumberASN1 = revokedCertificate.sub(0),
						certificateSerialNumberASN1.identifier?.tagNumber() == .integer,
						let certificateSerialNumber = (certificateSerialNumberASN1.value as? Data).flatMap({ normalizeCertificateId($0.map{ String(format: "%02x", $0) }.joined(separator: "-")) })
					else {
						throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: unexpected first element type in a revoked certificate sequence. CRL is \(crlASN1)"])
					}
					/* Note: The element could also be of time generalizedTime, but our CRL does not generate these type of times, so we don’t care.
					 * Let’s hope it never does! */
					guard
						let certificateRevocationDateASN1 = revokedCertificate.sub(1),
						(certificateRevocationDateASN1.identifier?.tagNumber() == .utcTime || certificateRevocationDateASN1.identifier?.tagNumber() == .generalizedTime),
						let certificateRevocationDate = certificateRevocationDateASN1.value as? Date
					else {
						throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: unexpected second element type in a revoked certificate sequence. CRL is \(crlASN1)"])
					}
					
					/* We ignore the extensions (if any) */
					
					if now < certificateRevocationDate {
						OfficeKitConfig.logger?.warning("Found certif \(certificateSerialNumber) in CRL which is not _yet_ revoked! Still considering as revoked.")
					}
					
					revokedIds.insert(certificateSerialNumber)
				}
			} else {
				delta += 1
			}
			
			/* We ignore extensions */
			
			der = d
			revokedCertificateIds = revokedIds
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
