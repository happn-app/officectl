/*
 * VaultCRL.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2022/09/28.
 */

import Foundation

import ASN1Decoder

import OfficeKit



/* <http://javadoc.iaik.tugraz.at/iaik_jce/current/iaik/x509/X509CRL.html>
 * <https://tools.ietf.org/html/rfc5280> § 5.1 */
struct VaultCRL {
	
	static func normalizeCertificateID(_ id: String) -> String {
		let characterSet: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
		var result = id.lowercased().drop(while: { $0 == "0" })
		result.removeAll{ !characterSet.contains($0) }
		return String(result)
	}
	
	let der: Data
	
	/* Computed from the der. */
	let revocationByCertificateID: [String: Date]
	
	init(der: Data) throws {
		let crlASN1Objects = try ASN1DERDecoder.decode(data: der)
		guard let crlASN1 = crlASN1Objects.onlyElement else {
			throw Err.invalidCRL(message: "Got \(crlASN1Objects.count) objects, expected exactly 1.")
		}
		guard crlASN1.identifier?.tagNumber() == .sequence else {
			throw Err.invalidCRL(message: "Expected SEQUENCE but got \(crlASN1).")
		}
		
		/* We do not concern ourselves w/ the second and third objects of the sequence.
		 * They are resp. the signature algorithm used to sign the CRL and the signature.
		 * Yes, we do not verify the signature of the CRL.
		 * It’s bad but verification would be too complex to implement rn. */
		/* TODO: Implement signature verification of the CRL. */
		guard let tbsCertList = crlASN1.sub(0), tbsCertList.identifier?.tagNumber() == .sequence else {
			throw Err.invalidCRL(message: "Expected SEQUENCE as first object of sequence got something else. CRL is \(crlASN1).")
		}
		
		var delta = 0
		
		/* We only implement CRL v2. */
		guard let version = tbsCertList.sub(0 - delta), version.identifier?.tagNumber() == .integer, version.value as? Data == Data([1]) else {
			throw Err.invalidCRL(message: "Expected INTEGER == 1 as first object of TBSCertList sequence, got something else. TBSCertList is \(tbsCertList).")
		}
		
		/* We ignore values of the field 1, 2, 3 and 4, resp. signature, issuer, this update time and next update time.
		 * We will simply check the types of the fields (which will also allow skipping absent optional values). */
		guard let signature = tbsCertList.sub(1 - delta), signature.identifier?.tagNumber() == .sequence else {
			throw Err.invalidCRL(message: "Expected SEQUENCE as second object of sequence, got something else. CRL is \(crlASN1).")
		}
		guard let issuer = tbsCertList.sub(2 - delta), issuer.identifier?.tagNumber() == .sequence else {
			throw Err.invalidCRL(message: "Expected SEQUENCE as third object of sequence, got something else. CRL is \(crlASN1).")
		}
		guard let thisUpdate = tbsCertList.sub(3 - delta), thisUpdate.identifier?.tagNumber() == .utcTime || thisUpdate.identifier?.tagNumber() == .generalizedTime else {
			throw Err.invalidCRL(message: "Expected UTC Time or GeneralizedTime as fourth object of sequence, got something else. CRL is \(crlASN1).")
		}
		if let nextUpdate = tbsCertList.sub(4 - delta), nextUpdate.identifier?.tagNumber() == .utcTime || nextUpdate.identifier?.tagNumber() == .generalizedTime {
			/* We do nothing for now (or maybe ever tbh). */
		} else {
			delta += 1
		}
		
		var revocationByCertificateID = [String: Date]()
		/* The revoked certificates list is optional. */
		if let revokedCertificates = tbsCertList.sub(5 - delta), revokedCertificates.identifier?.tagNumber() == .sequence {
			let now = Date()
			for i in 0..<revokedCertificates.subCount() {
				guard let revokedCertificate = revokedCertificates.sub(i) else {
					throw Err.invalidCRL(message: "Cannot get certificate at index \(i) inside the revoked certificates sequence. CRL is \(crlASN1).")
				}
				guard revokedCertificate.identifier?.tagNumber() == .sequence else {
					if revokedCertificate.identifier?.tagNumber() != .endOfContent {
						throw Err.invalidCRL(message: "Expected SEQUENCE or END_OF_CONTENT for certificate at index \(i) inside the revoked certificates sequence, got something else. CRL is \(crlASN1).")
					} else {
						continue
					}
				}
				guard revokedCertificate.subCount() == 2 || revokedCertificate.subCount() == 3 else {
					throw Err.invalidCRL(message: "Unexpected count of elements in a revoked certificate sequence. CRL is \(crlASN1).")
				}
				guard
					let certificateSerialNumberASN1 = revokedCertificate.sub(0),
					certificateSerialNumberASN1.identifier?.tagNumber() == .integer,
					let certificateID = ((certificateSerialNumberASN1.value as? Data).flatMap{ Self.normalizeCertificateID($0.map{ String(format: "%02x", $0) }.joined(separator: "-")) })
				else {
					throw Err.invalidCRL(message: "Unexpected first element type in a revoked certificate sequence. CRL is \(crlASN1).")
				}
				/* Note: The element could also be of time generalizedTime, but Vault PKI does not generate these type of times, so we don’t care.
				 * Let’s hope it never does! */
				guard
					let certificateRevocationDateASN1 = revokedCertificate.sub(1),
					(certificateRevocationDateASN1.identifier?.tagNumber() == .utcTime || certificateRevocationDateASN1.identifier?.tagNumber() == .generalizedTime),
					let certificateRevocationDate = certificateRevocationDateASN1.value as? Date
				else {
					throw Err.invalidCRL(message: "Unexpected second element type in a revoked certificate sequence. CRL is \(crlASN1).")
				}
				
				/* We ignore the extensions (if any) */
				
				if revocationByCertificateID[certificateID] != nil {
					Conf.logger?.warning("Found certificate ID multiple times in CRL; last one wins.", metadata: ["certificate_id": "\(certificateID)"])
				}
				revocationByCertificateID[certificateID] = certificateRevocationDate
			}
		} else {
			delta += 1
		}
		
		/* We ignore extensions */
		
		self.der = der
		self.revocationByCertificateID = revocationByCertificateID
	}
	
}
