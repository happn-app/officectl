/*
 * GetGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/09/2018.
 */

import Foundation

import AsyncOperationResult
import RetryingOperation



/* https://developers.google.com/admin-sdk/directory/v1/reference/users/get */
public class GetGoogleUserOperation : RetryingOperation {
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user")
	
	public let connector: GoogleJWTConnector
	
	public let userKey: String
	
	public private(set) var result = AsyncOperationResult<GoogleUser>.error(OperationIsNotFinishedError())
	
	public init(userKey k: String, connector c: GoogleJWTConnector) {
		userKey = k
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		let urlComponents = URLComponents(url: URL(string: userKey, relativeTo: URL(string: "https://www.googleapis.com/admin/directory/v1/users/")!)!, resolvingAgainstBaseURL: true)!
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		#if !os(Linux)
			decoder.keyDecodingStrategy = .useDefaultKeys
		#endif
		let op = AuthenticatedJSONOperation<GoogleUser>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.decodedObject else {
				self.result = .error(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the user"]))
				self.baseOperationEnded()
				return
			}
			
			self.result = .success(o)
			self.baseOperationEnded()
		}
		op.start()
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
