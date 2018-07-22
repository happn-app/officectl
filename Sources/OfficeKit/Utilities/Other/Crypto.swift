/*
 * Crypto.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation
#if canImport(Security)
	import Security
#else
	public typealias SecKey = Data
	import Crypto
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
			guard let jwtRequestSignature = try? RSA.SHA256.sign(jwtRequestNoSignatureData, key: RSAKey.private(pem: privateKey)) else {
				throw NSError(domain: "com.happn.officectl.crypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
			}
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
