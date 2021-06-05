/*
 * Crypto.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

/* A note about this file: JWTKit did not exist (at least not on this form)
 * previously. So we created Crypto.swift to handle signing using
 * Security.framework on macOS-like platforms, and Vapor’s crypto framework
 * (basically a wrapper around OpenSSL) on Linux.
 * As time and releases went by on macOS and Vapor sides, things changed. Now
 * the “correct” way to sign a JWT token is by using JWTKit, whether you’re on
 * macOS on Linux. I still kept this file to avoir changing the code everywhere,
 * but it should be easy to do. */

import Foundation
#if canImport(Security)
	import Security
#else
	import JWTKit
//	import OpenCrypto
	public typealias SecKey = Data
#endif



struct Crypto {
	
	private init() {}
	
	static func privateKey(pemURL url: URL) throws -> SecKey {
		return try privateKey(pemData: Data(contentsOf: url))
	}
	
	#if canImport(Security)
		static func privateKey(pemData data: Data) throws -> SecKey {
			var keys: CFArray?
			guard
				SecItemImport(data as CFData, nil, nil, nil, [], nil, nil, &keys) == 0,
				let key = (keys as? [SecKey])?.first
			else {
				throw NSError(domain: "com.happn.officectl.crypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read the private key."])
			}
			return key
		}
	
		/** Signed with “RS256” algorithm. */
		static func createRS256JWT(payload: [String: Any?], privateKey: SecKey) throws -> String {
			let jwtRequestNoSignatureString = try jwtRS256RequestNoSignature(payload: payload)
			let jwtRequestNoSignatureData = Data(jwtRequestNoSignatureString.utf8)
			guard
				let signer = SecSignTransformCreate(privateKey, nil),
				SecTransformSetAttribute(signer, kSecDigestTypeAttribute, kSecDigestSHA2, nil),
				SecTransformSetAttribute(signer, kSecDigestLengthAttribute, NSNumber(value: 256), nil),
				SecTransformSetAttribute(signer, kSecTransformInputAttributeName, jwtRequestNoSignatureData as CFData, nil),
				let jwtRequestSignature = SecTransformExecute(signer, nil) as? Data
			else {
				throw NSError(domain: "com.happn.officectl.crypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
			}
			return jwtRequestNoSignatureString + "." + jwtRequestSignature.base64EncodedString()
		}
	#else
		static func privateKey(pemData data: Data) throws -> SecKey {
			return data
		}
	
		/** Signed with “RS256” algorithm. */
		static func createRS256JWT(payload: [String: Any?], privateKey pemData: Data) throws -> String {
			let jwtRequestNoSignatureString = try jwtRS256RequestNoSignature(payload: payload)
			let jwtRequestNoSignatureData = Data(jwtRequestNoSignatureString.utf8)
			let jwtRequestSignature = try Data(JWTSigner.rs256(key: RSAKey.private(pem: pemData)).algorithm.sign(jwtRequestNoSignatureData))
			return jwtRequestNoSignatureString + "." + jwtRequestSignature.base64EncodedString()
		}
	#endif
	
	private static func jwtRS256RequestNoSignature(payload: [String: Any?]) throws -> String {
		let jwtRequestHeader = ["typ": "JWT", "alg": "RS256"]
		let jwtRequestHeaderBase64  = try JSONEncoder().encode(jwtRequestHeader).base64EncodedString()
		let jwtRequestPayloadBase64 = try JSONSerialization.data(withJSONObject: payload, options: []).base64EncodedString()
		let jwtRequestNoSignature = jwtRequestHeaderBase64 + "." + jwtRequestPayloadBase64
		return jwtRequestNoSignature
	}
	
}
