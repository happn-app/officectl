/*
 * ExternalServiceAuthenticator.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import Crypto



public class ExternalServiceAuthenticator : Authenticator {
	
	public typealias RequestType = URLRequest
	
	public var secret: Data
	
	public init(secret s: Data) {
		secret = s
	}
	
	public func authenticate(request: URLRequest, handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) {
		/* TODO one day, maybe: https://datatracker.ietf.org/doc/draft-cavage-http-signatures/?include_text=1.
		 * Note that at the time of writing, the revision is spec 11 and is not finalized. */
		do {
			var request = request
			
			let validityEnd   = "\(Int((Date() + 9).timeIntervalSince1970))"
			let validityStart = "\(Int((Date() - 9).timeIntervalSince1970))"
			
			guard let urlPath = request.url?.path else {
				throw InternalError(message: "No path in the URL request to authenticate")
			}
			let body = request.httpBody ?? Data()
			
			let sepData = Data(":".utf8)
			let signedData = (
				Data(validityStart.utf8).base64EncodedData() + sepData +
				Data(validityEnd.utf8).base64EncodedData()   + sepData +
				Data(urlPath.utf8).base64EncodedData()       + sepData +
				body.base64EncodedData()
			)
			
			let signature = try HMAC.SHA256.authenticate(signedData, key: secret)
			request.addValue(validityStart + ":" + validityEnd + ":" + signature.base64EncodedString(), forHTTPHeaderField: "Officectl-Signature")
			handler(.success(request), nil)
		} catch {
			handler(.failure(error), nil)
		}
	}
	
}
