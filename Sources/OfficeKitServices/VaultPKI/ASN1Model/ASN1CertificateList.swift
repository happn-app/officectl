/*
 * VaultCRL.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2022/09/28.
 */

import Foundation

import SwiftASN1
import X509

import OfficeKit



/* <http://javadoc.iaik.tugraz.at/iaik_jce/current/iaik/x509/X509CRL.html>
 * <https://tools.ietf.org/html/rfc5280> § 5.1
 *
 * CertificateList  ::=  SEQUENCE  {
 *      tbsCertList          TBSCertList,
 *      signatureAlgorithm   AlgorithmIdentifier,
 *      signatureValue       BIT STRING  }
 */
struct ASN1CertificateList : DERImplicitlyTaggable, Sendable {
	
	static var defaultIdentifier: ASN1Identifier {
		.sequence
	}
	
	var tbsCertList: ASN1TBSCertList
	var signatureAlgorithm: ASN1AlgorithmIdentifier
	var signatureValue: ASN1BitString
	
	init(tbsCertList: ASN1TBSCertList, signatureAlgorithm: ASN1AlgorithmIdentifier, signatureValue: ASN1BitString) {
		self.tbsCertList = tbsCertList
		self.signatureAlgorithm = signatureAlgorithm
		self.signatureValue = signatureValue
	}
	
	init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
		self = try DER.sequence(rootNode, identifier: identifier, { nodes in
			let certList = try ASN1TBSCertList(derEncoded: &nodes)
			let signatureAlgorithm = try ASN1AlgorithmIdentifier(derEncoded: &nodes)
			let signatureValue = try ASN1BitString(derEncoded: &nodes)
			
			return .init(tbsCertList: certList, signatureAlgorithm: signatureAlgorithm, signatureValue: signatureValue)
		})
	}
	
	func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
		try coder.appendConstructedNode(identifier: identifier, { coder in
			try coder.serialize(tbsCertList)
			try coder.serialize(signatureAlgorithm)
			try coder.serialize(signatureValue)
		})
	}
	
	static func normalizeCertificateID(_ id: String) -> String {
		let characterSet: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
		var result = id.lowercased().drop(while: { $0 == "0" })
		result.removeAll{ !characterSet.contains($0) }
		return String(result)
	}
	
	static func normalizeCertificateID(_ id: Certificate.SerialNumber) -> String {
		/* id.description joins all the bytes but does not force them on 2 bytes… */
		let str = id.bytes.lazy.map{ String(format: "%02x", $0) }.joined(/*separator: ":"*/)
		return normalizeCertificateID(String(str))
	}
	
}
