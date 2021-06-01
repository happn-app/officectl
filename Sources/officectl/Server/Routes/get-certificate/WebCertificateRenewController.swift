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

import ASN1Decoder
import GenericJSON
import OfficeKit
import URLRequestOperation
import Vapor



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
		let issuerName = try nil2throw(officectlConfig.tmpVaultIssuerName)
		let additionalActiveIssuers = officectlConfig.tmpVaultAdditionalActiveIssuers ?? []
		let additionalPassiveIssuers = officectlConfig.tmpVaultAdditionalPassiveIssuers ?? []
		let additionalCertificates = officectlConfig.tmpVaultAdditionalCertificates ?? []
		let token = try nil2throw(officectlConfig.tmpVaultToken)
		let ttl = try nil2throw(officectlConfig.tmpVaultTTL)
		let expirationLeeway = try nil2throw(officectlConfig.tmpVaultExpirationLeeway)
		let expectedExpiration = Date() + expirationLeeway
		
		func authenticateSync(_ request: inout URLRequest) -> Void {
			request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
		}
		
		func authenticate(_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void {
			var request = request
			authenticateSync(&request)
			handler(.success(request), nil)
		}
		
		let getCertificatesFutures = ([issuerName] + additionalActiveIssuers).map{ issuerName in
			req.eventLoop.future()
			.flatMap{ _ -> EventLoopFuture<CRL> in
				/* Let’s get the CRL */
				var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("crl"))
				authenticateSync(&urlRequest)
				let op = URLRequestOperation(request: urlRequest)
				return EventLoopFuture<CRL>.future(from: op, on: req.eventLoop, resultRetriever: { op in
					guard let data = op.fetchedData else {
						throw op.finalError ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error fetching the CRL"])
					}
					return try CRL(der: data)
				})
			}
			.flatMapThrowing{ crl -> EventLoopFuture<(CertificateSerialsList, CRL)> in
				/* Let’s fetch the list of current certificates in the vault */
				var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("certs"))
				urlRequest.httpMethod = "LIST"
				let op = AuthenticatedJSONOperation<VaultResponse<CertificateSerialsList>>(request: urlRequest, authenticator: authenticate, retryInfoRecoveryHandler: { operation, error, handler in
					if (operation.urlResponse as? HTTPURLResponse)?.statusCode == 404,
						let data = operation.fetchedData,
						let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any?],
						(jsonObject["errors"] as? [Any?])?.isEmpty ?? false
					{
						/* When there are no certificates in the PKI, vault returns a
						 * fucking 404! */
						(operation as! AuthenticatedJSONOperation<VaultResponse<CertificateSerialsList>>).fetchedObject = .init(data: .init(keys: []))
						return handler(.doNotRetry, operation.currentURLRequest, nil)
					}
					handler(.doNotRetry, operation.currentURLRequest, error)
				})
				return EventLoopFuture<VaultResponse<CertificateSerialsList>>.future(from: op, on: req.eventLoop).map{ ($0.data, crl) }
			}
			.flatMap{ $0 }
			.flatMap{ (certificatesList, crl) -> EventLoopFuture<[(id: String, issuerName: String, certif: X509Certificate)]> in
				/* Get the list of certificates to revoke */
				let futures = certificatesList.keys.compactMap{ id -> EventLoopFuture<(id: String, issuerName: String, certif: X509Certificate)?>? in
					/* If the certificate is already revoked, we don’t have to do
					 * anything w/ it. */
					guard !crl.revokedCertificateIds.contains(normalizeCertificateId(id)) else {
						return nil
					}
					
					let urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("cert").appendingPathComponent(id))
					let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
					return EventLoopFuture<VaultResponse<CertificateContainer>>.future(from: op, on: req.eventLoop).flatMapThrowing{ certificateResponse in
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
				return EventLoopFuture.reduce([(id: String, issuerName: String, certif: X509Certificate)](), futures, on: req.eventLoop, { full, new in
					guard let new = new else {return full}
					return full + [new]
				})
			}
		}
		return EventLoopFuture<[(id: String, issuerName: String, certif: X509Certificate)]>.reduce([], getCertificatesFutures, on: req.eventLoop, +)
		.flatMapThrowing{ certificatesToRevoke -> [(id: String, issuerName: String)] in
			/* We check if all of the certificates to revoke will expire in less
			 * than n seconds (where n is defined in the conf). If the user is
			 * admin we don’t do this check (admin can renew any certif they want
			 * whenever they want). */
			if !loggedInUser.isAdmin {
				try certificatesToRevoke.forEach{ idAndCertif in
					let certif = idAndCertif.certif
					guard !certif.checkValidity(expectedExpiration) else {
						throw InvalidArgumentError(message: "You’ve got at least one certificate still valid, please use it or see an ops!")
					}
				}
			}
			return certificatesToRevoke.map{ (id: $0.id, issuerName: $0.issuerName) }
		}
		.flatMapThrowing{ certificateIdsWithIssuersToRevoke -> EventLoopFuture<Void> in
			/* Revoke the certificates to revoke */
			try req.application.auditLogger.log(action: "Revoking \(certificateIdsWithIssuersToRevoke.count) certificate(s): \(certificateIdsWithIssuersToRevoke.map{ $0.issuerName + ":" + $0.id }.joined(separator: " ")).", source: .web)
			let futures = certificateIdsWithIssuersToRevoke.map{ idAndIssuer -> EventLoopFuture<Void> in
				let (id, issuerName) = idAndIssuer
				var urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("revoke"))
				urlRequest.httpMethod = "POST"
				let json = JSON(dictionaryLiteral: ("serial_number", JSON(stringLiteral: id)))
				urlRequest.httpBody = try! JSONEncoder().encode(json)
				let op = AuthenticatedJSONOperation<VaultResponse<RevocationResult?>>(request: urlRequest, authenticator: authenticate, retryInfoRecoveryHandler: { op, err, completionHandler in
					if
						let op = op as? AuthenticatedJSONOperation<VaultResponse<RevocationResult?>>,
						op.fetchedData?.count == 0,
						(op.urlResponse as? HTTPURLResponse)?.statusCode == 204
					{
						/* Vault returns an empty reply if revoking an expired
						 * certificate, so we erase the error in case we get an empty
						 * reply from the Vault API. */
						op.fetchedObject = VaultResponse<RevocationResult?>(data: nil)
						return completionHandler(.doNotRetry, op.currentURLRequest, nil)
					}
					return completionHandler(.doNotRetry, op.currentURLRequest, err)
				})
				return EventLoopFuture<VaultResponse<RevocationResult?>>.future(from: op, on: req.eventLoop).map{ _ in return () }
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
			/* We recreate the CA chain because we can have more than one, and
			 * because vault does not add the root CA anyway… */
			var newCertificate = newCertificate
			newCertificate.caChain.removeAll()
			/* Let’s retrieve CAs */
			let futures1 = ([issuerName] + additionalActiveIssuers + additionalPassiveIssuers).map{ issuerName -> EventLoopFuture<CertificateContainer> in
				let urlRequest = URLRequest(url: baseURL.appendingPathComponent(issuerName).appendingPathComponent("cert").appendingPathComponent("ca"))
				let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
				return EventLoopFuture<VaultResponse<CertificateContainer>>.future(from: op, on: req.eventLoop).map{ $0.data }
			}
			/* Let’s retrieve additional certificates */
			let futures2 = additionalCertificates.map{ additionalCertificate -> EventLoopFuture<CertificateContainer> in
				let urlRequest = URLRequest(url: baseURL.appendingPathComponent(additionalCertificate.issuer).appendingPathComponent("cert").appendingPathComponent(additionalCertificate.id))
				let op = AuthenticatedJSONOperation<VaultResponse<CertificateContainer>>(request: urlRequest, authenticator: authenticate)
				return EventLoopFuture<VaultResponse<CertificateContainer>>.future(from: op, on: req.eventLoop).map{ $0.data }
			}
			return EventLoopFuture<NewCertificate>.reduce(into: newCertificate, futures1 + futures2, on: req.eventLoop, { certif, currentChainCertificate in
				certif.caChain.append(currentChainCertificate.pem)
			})
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
			
			/* We do not concern ourselves w/ the second and third objects of the
			 * sequence. They are resp. the signature algorithm used to sign the
			 * CRL and the signature.
			 * Yes, we do not verify the signature of the CRL. It’s bad but
			 * verification would be too complex to implement rn. */
			guard let tbsCertList = crlASN1.sub(0), tbsCertList.identifier?.tagNumber() == .sequence else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected SEQUENCE as first object of sequence got something else. CRL is \(crlASN1)"])
			}
			
			var delta = 0
			
			/* We only implement CRL v2 */
			guard let version = tbsCertList.sub(0 - delta), version.identifier?.tagNumber() == .integer, version.value as? Data == Data([1]) else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot parse CRL: expected INTEGER == 1 as first object of TBSCertList sequence, got something else. TBSCertList is \(tbsCertList)"])
			}
			
			/* We ignore values of the field 1, 2, 3 and 4, resp. signature,
			 * issuer, this update time and next update time.
			 * We will simply check the types of the fields (which will also allow
			 * skipping absent optional values). */
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
					/* Note: The element could also be of time generalizedTime, but
					 * our CRL does not generate these type of times, so we don’t
					 * care. Let’s hope it never does! */
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
