/*
 * Crypto.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

/* A note about this file: JWTKit did not exist (at least not on this form) previously.
 * So we manually signed the JWT tokens.
 * Now we should use JWTKit properly but I still kept this file to avoir changing the code everywhere.
 * It should not be too difficult to do if we want to. */

import Foundation
import JWTKit



struct Crypto {
	
	private init() {}
	
	static func privateKey(pemURL url: URL) throws -> Data {
		return try privateKey(pemData: Data(contentsOf: url))
	}
	
	static func privateKey(pemData data: Data) throws -> Data {
		return data
	}
	
	/** Signed with “RS256” algorithm. */
	static func createRS256JWT(payload: [String: Any?], privateKey pemData: Data) throws -> String {
		let jwtRequestNoSignatureString = try jwtRS256RequestNoSignature(payload: payload)
		let jwtRequestNoSignatureData = Data(jwtRequestNoSignatureString.utf8)
		let jwtRequestSignature = try Data(JWTSigner.rs256(key: RSAKey.private(pem: pemData)).algorithm.sign(jwtRequestNoSignatureData))
		return jwtRequestNoSignatureString + "." + jwtRequestSignature.base64EncodedString()
	}
	
	private static func jwtRS256RequestNoSignature(payload: [String: Any?]) throws -> String {
		let jwtRequestHeader = ["typ": "JWT", "alg": "RS256"]
		let jwtRequestHeaderBase64  = try JSONEncoder().encode(jwtRequestHeader).base64EncodedString()
		let jwtRequestPayloadBase64 = try JSONSerialization.data(withJSONObject: payload, options: []).base64EncodedString()
		let jwtRequestNoSignature = jwtRequestHeaderBase64 + "." + jwtRequestPayloadBase64
		return jwtRequestNoSignature
	}
	
}
