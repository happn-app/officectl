/*
 * OfficeKitAuthenticator.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import Crypto
import TaskQueue



public final actor OfficeKitAuthenticator : Authenticator, HasTaskQueue {
	
	public typealias RequestType = URLRequest
	
	public var secret: Data
	
	public init(secret: Data) {
		self.secret = secret
	}
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* TODO one day, maybe: <https://datatracker.ietf.org/doc/draft-ietf-httpbis-message-signatures/>.
		 * Note that at the time of writing this is still an active proposal. */
		let validityEnd   = "\(Int((Date() + 9).timeIntervalSince1970))"
		let validityStart = "\(Int((Date() - 9).timeIntervalSince1970))"
		
		guard let urlPath = request.url?.path else {
			throw Err.internalError
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
