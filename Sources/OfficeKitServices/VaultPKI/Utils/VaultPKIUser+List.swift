/*
 * VaultPKIUser+List.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/26.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ASN1Decoder
import URLRequestOperation

import OfficeKit



extension VaultPKIUser {
	
	static func getAll(from issuerName: String, includeRevoked: Bool = false, vaultBaseURL: URL, vaultAuthenticator: VaultPKIAuthenticator) async throws -> [VaultPKIUser] {
		let requestProcessor = AuthRequestProcessor(vaultAuthenticator)
		
		/* Let’s get the CRL. */
		let opCRL = try URLRequestDataOperation.forData(url: vaultBaseURL.appending("v1", issuerName, "crl"), requestProcessors: [requestProcessor])
		let revocationByCertificateID = try await VaultCRL(der: opCRL.startAndGetResult().result).revocationByCertificateID
		
		/* Let’s fetch the list of current certificates in the vault. */
		let opListCurrentCertifs = URLRequestDataOperation<VaultResponse<VaultCertificateSerialsList>>.forAPIRequest(
			url: try vaultBaseURL.appending("v1", issuerName, "certs"), method: "LIST",
			errorType: VaultError.self, requestProcessors: [requestProcessor],
			resultProcessorModifier: { rp in
				rp.flatMapError{ (error, response) in
					/* When there are no certificates in the PKI, vault returns a fucking 404!
					 * With a response like so '{"errors":[]}'. */
					if (response as? HTTPURLResponse)?.statusCode == 404,
						let e = (error as? APIResultErrorWrapper<VaultError>)?.apiError,
						e.errors.isEmpty
					{
						return VaultResponse(data: VaultCertificateSerialsList(keys: []))
					}
					throw error
				}
			}, retryProviders: []
		)
		let certificatesList = try await opListCurrentCertifs.startAndGetResult().result.data
		
		/* Note: An alternative to the flatMapError in the resultProcessorModifier in the operation above would be no modifier and catching the error.
		 * An example of implementation (untested):
		 * 	let certificatesList: VaultCertificateSerialsList
		 * 	do {
		 * 		certificatesList = try await opListCurrentCertifs.startAndGetResult().result.data
		 * 	} catch let e as URLRequestOperationError where e.apiError(VaultError.self)?.errors.isEmpty ?? false {
		 * 		certificatesList = .init(keys: [])
		 * 	}
		 */
		
		/* Get the list of certificates (which are the users). */
		return try await certificatesList.keys.concurrentCompactMap{ id -> VaultPKIUser? in
			let revocationDate = revocationByCertificateID[VaultCRL.normalizeCertificateID(id)]
			guard includeRevoked || revocationDate == nil else {
				return nil
			}
			let certificateResponse = try await URLRequestDataOperation<VaultResponse<VaultCertificateContainer>>.forAPIRequest(
				url: try vaultBaseURL.appending("v1", issuerName, "cert", id),
				requestProcessors: [requestProcessor], retryProviders: []
			).startAndGetResult().result
			
			guard let subjectDNStr = certificateResponse.data.certificate.subjectDistinguishedName else {
				throw Err.foundInvalidCertificateWithNoDN
			}
			let subjectDN = try LDAPDistinguishedName(string: subjectDNStr)
			
			guard let dnValue = (subjectDN.values.filter{ $0.key == "CN" }.onlyElement) else {
				throw Err.foundInvalidCertificateWithNoUnambiguousCNInDN(dn: subjectDN)
			}
			let subjectCN = dnValue.value
			
			guard let validityStartDate = certificateResponse.data.certificate.notBefore else {
				throw Err.foundInvalidCertificateWithNoValidityStartDate(dn: subjectDN)
			}
			guard let expirationDate = certificateResponse.data.certificate.notAfter else {
				throw Err.foundInvalidCertificateWithNoExpirationDate(dn: subjectDN)
			}
			
			return VaultPKIUser(cn: subjectCN, certifID: id, certificateMetadata: .init(
				keyUsageHasServerAuth: certificateResponse.data.certificate.extendedKeyUsage.contains("1.3.6.1.5.5.7.3.1"/*serverAuth*/),
				keyUsageHasClientAuth: certificateResponse.data.certificate.extendedKeyUsage.contains("1.3.6.1.5.5.7.3.2"/*clientAuth*/),
				validityStartDate: validityStartDate,
				expirationDate: expirationDate,
				revocationDate: revocationDate,
				underlyingCertif: certificateResponse.data.certificate
			))
		}
	}
	
}
