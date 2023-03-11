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

import SwiftASN1
import URLRequestOperation
import X509

import OfficeKit



extension CertificateMetadata {
	
	static func getAll(from issuerName: String, includeRevoked: Bool = false, vaultBaseURL: URL, vaultAuthenticator: VaultPKIAuthenticator) async throws -> [CertificateMetadata] {
		let requestProcessor = AuthRequestProcessor(vaultAuthenticator)
		
		/* Let’s get the CRL. */
		let opCRL = try URLRequestDataOperation.forData(url: vaultBaseURL.appending("v1", issuerName, "crl"), requestProcessors: [requestProcessor])
		let revocationList = try await ASN1CertificateList(derEncoded: DER.parse([UInt8](opCRL.startAndGetResult().result)))//.revocationByCertificateID
		var revocationByCertificateID = [String: Date]()
		for revokedCert in revocationList.tbsCertList.revokedCertificates ?? [] {
			/* TODO: Check conversion from ASN1Time to Date is ok and check we do not have double certif revocation (take earliest date if we do, I guess?). */
			revocationByCertificateID[ASN1CertificateList.normalizeCertificateID(revokedCert.userCertificate)] = Date(revokedCert.revocationDate)
		}
		
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
		
		/* Get the list of certificates. */
		return try await certificatesList.keys.concurrentCompactMap{ (id: String) -> CertificateMetadata? in
			let revocationDate = revocationByCertificateID[ASN1CertificateList.normalizeCertificateID(id)]
			/* TODO: Check the actual revocation date? */
			guard includeRevoked || revocationDate == nil else {
				return nil
			}
			let certificateResponse = try await URLRequestDataOperation<VaultResponse<VaultCertificateContainer>>.forAPIRequest(
				url: try vaultBaseURL.appending("v1", issuerName, "cert", id),
				requestProcessors: [requestProcessor], retryProviders: []
			).startAndGetResult().result
			
			let subjectDN = try LDAPDistinguishedName(string: certificateResponse.data.certificate.subject.description)
			
			func asn1AnyToString(_ obj: ASN1Any?) -> String? {
				if let str = (obj.flatMap{ try? ASN1UTF8String(     asn1Any: $0) }).flatMap(String.init) {return str}
				if let str = (obj.flatMap{ try? ASN1PrintableString(asn1Any: $0) }).flatMap(String.init) {return str}
				return nil
			}
			guard let cnAttributeValue = (certificateResponse.data.certificate.subject.compactMap{ $0.filter{ $0.type == .RDNAttributeType.commonName }.onlyElement }.onlyElement?.value),
					let subjectCN = asn1AnyToString(cnAttributeValue)
			else {
				throw Err.foundInvalidCertificateWithNoUnambiguousCNInDN(dn: subjectDN)
			}
			
			return try CertificateMetadata(
				cn: subjectCN,
				certifID: id,
				keyUsageHasServerAuth: certificateResponse.data.certificate.extensions.extendedKeyUsage?.contains(.serverAuth) ?? false,
				keyUsageHasClientAuth: certificateResponse.data.certificate.extensions.extendedKeyUsage?.contains(.clientAuth) ?? false,
				validityStartDate: certificateResponse.data.certificate.notValidBefore,
				expirationDate: certificateResponse.data.certificate.notValidAfter,
				revocationDate: revocationDate,
				underlyingCertif: certificateResponse.data.certificate
			)
		}
	}
	
}
