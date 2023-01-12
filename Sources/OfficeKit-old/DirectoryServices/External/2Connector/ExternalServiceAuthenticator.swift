/*
 * ExternalServiceAuthenticator.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import Crypto
import TaskQueue



public final actor ExternalServiceAuthenticator : Authenticator, HasTaskQueue {
	
	public typealias RequestType = URLRequest
	
	public var secret: Data
	
	public init(secret s: Data) {
		secret = s
	}
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* TODO one day, maybe: <https://datatracker.ietf.org/doc/draft-cavage-http-signatures/?include_text=1>.
		 * Note that at the time of writing, the revision is spec 11 and is not finalized. */
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
		
		let signature = HMAC<SHA256>.authenticationCode(for: signedData, using: SymmetricKey(data: secret))
		
		var request = request
		request.addValue(validityStart + ":" + validityEnd + ":" + Data(signature).base64EncodedString(), forHTTPHeaderField: "Officectl-Signature")
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
}
