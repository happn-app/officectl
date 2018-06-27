/*
 * JWT.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



struct JWT {
	
	private init() {}
	
	/** Encode with “RS256” algorithm. */
	static func encode(jwtRequest jwtRequestContent: [String: Any?], privateKey: SecKey) throws -> String {
		let jwtRequestHeader = ["typ": "JWT", "alg": "RS256"]
		let jwtRequestHeaderBase64  = try JSONEncoder().encode(jwtRequestHeader).base64EncodedString()
		let jwtRequestContentBase64 = try JSONSerialization.data(withJSONObject: jwtRequestContent, options: []).base64EncodedString()
		let jwtRequestSignedString = jwtRequestHeaderBase64 + "." + jwtRequestContentBase64
		guard
			let jwtRequestSignedData = jwtRequestSignedString.data(using: .utf8),
			let signer = SecSignTransformCreate(privateKey, nil),
			SecTransformSetAttribute(signer, kSecDigestTypeAttribute, kSecDigestSHA2, nil),
			SecTransformSetAttribute(signer, kSecDigestLengthAttribute, NSNumber(value: 256), nil),
			SecTransformSetAttribute(signer, kSecTransformInputAttributeName, jwtRequestSignedData as CFData, nil),
			let jwtRequestSignature = SecTransformExecute(signer, nil) as? Data
		else {
			throw NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
		}
		return jwtRequestSignedString + "." + jwtRequestSignature.base64EncodedString()
	}
	
}
