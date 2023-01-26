/*
 * VaultCertificateContainer.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2022/09/28.
 */

import Foundation

import ASN1Decoder



struct VaultCertificateContainer : Decodable {
	
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
