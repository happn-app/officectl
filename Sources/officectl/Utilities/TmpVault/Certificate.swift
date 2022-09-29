/*
 * Certificate.swift
 * 
 *
 * Created by François Lamboley on 2022/09/28.
 * 
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ASN1Decoder
import URLRequestOperation

import OfficeKit



struct Certificate {
	
	static func getAll(from issuerName: String, includeRevoked: Bool = false, vaultBaseURL: URL, vaultAuthenticator: AuthRequestProcessor) async throws -> [Certificate] {
		/* Let’s get the CRL */
		let opCRL = try URLRequestDataOperation.forData(url: vaultBaseURL.appending(issuerName, "crl"), requestProcessors: [vaultAuthenticator])
		let revokedCertificateIDs = try await VaultCRL(der: opCRL.startAndGetResult().result).revokedCertificateIDs
		
		/* Let’s fetch the list of current certificates in the vault */
		let opListCurrentCertifs = URLRequestDataOperation<VaultResponse<VaultCertificateSerialsList>>.forAPIRequest(
			url: try vaultBaseURL.appending(issuerName, "certs"), method: "LIST",
			errorType: VaultError.self, requestProcessors: [vaultAuthenticator],
			resultProcessorModifier: { rp in
				rp.flatMapError{ (error, response) in
					/* When there are no certificates in the PKI, vault returns a fucking 404!
					 * With a response like so '{"errors":[]}'. */
					if (response as? HTTPURLResponse)?.statusCode == 404,
						let e = error as? URLRequestOperationError.APIResultErrorWrapper<VaultError>,
						e.error.errors.isEmpty
					{
						return VaultResponse(data: VaultCertificateSerialsList(keys: []))
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
			let isRevoked = revokedCertificateIDs.contains(normalizeCertificateID(id))
			guard includeRevoked || !isRevoked else {
				return nil
			}
			let certificateResponse = try await URLRequestDataOperation<VaultResponse<VaultCertificateContainer>>.forAPIRequest(
				url: try vaultBaseURL.appending(issuerName, "cert", id),
				requestProcessors: [vaultAuthenticator], retryProviders: []
			).startAndGetResult().result
			guard let subjectDNStr = certificateResponse.data.certificate.subjectDistinguishedName else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get certificate DN for\n\(certificateResponse.data.pem)"])
			}
			let subjectDN = try LDAPDistinguishedName(string: subjectDNStr)
			guard let dnValue = (subjectDN.values.filter{ $0.key == "CN" }.onlyElement) else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get certificate CN from DN “\(subjectDN)”"])
			}
			let subjectCN = dnValue.value
			return Certificate(id: id, commonName: subjectCN, issuerName: issuerName, certif: certificateResponse.data.certificate, isRevoked: isRevoked)
		}
	}
	
	var id: String
	var commonName: String
	
	var issuerName: String
	var certif: X509Certificate
	
	var isRevoked: Bool
	
}
