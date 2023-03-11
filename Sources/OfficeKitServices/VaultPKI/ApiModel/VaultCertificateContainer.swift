/*
 * VaultCertificateContainer.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2022/09/28.
 */

import Foundation

import X509



struct VaultCertificateContainer : Decodable {
	
	var pem: String
	var certificate: Certificate
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let pemStr = try container.decode(String.self, forKey: .certificate)
		/* First we must convert the PEM to DER.
		 * This consist in stripping the armor and converting the base64 string to binary.
		 * Weirdly swift-certificates does not do this itself (yet?)… */
		let der = try Self.pem2der(pemStr)
		certificate = try Certificate(derEncoded: Array(der))
		pem = pemStr
	}
	
	private enum CodingKeys : String, CodingKey {
		case certificate
	}
	
	private static func pem2der(_ pem: String) throws -> Data {
		let prefix = "-----BEGIN CERTIFICATE-----\n"
		let suffix = "\n-----END CERTIFICATE-----"
		
		let pem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
		guard pem.hasPrefix(prefix), pem.hasSuffix(suffix) else {
			throw Err.invalidPEM(pem: pem)
		}
		
		let base64Str = pem[pem.index(pem.startIndex, offsetBy: prefix.count)..<pem.index(pem.endIndex, offsetBy: -suffix.count)]
			.replacingOccurrences(of: "\n", with: "")
		guard let der = Data(base64Encoded: Data(base64Str.utf8)) else {
			throw Err.invalidPEM(pem: pem)
		}
		return der
	}
	
}
