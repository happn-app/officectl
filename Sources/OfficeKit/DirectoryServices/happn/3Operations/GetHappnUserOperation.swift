/*
 * GetHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 30/08/2019.
 */

import Foundation

import RetryingOperation



public final class GetHappnUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = HappnUser
	
	public static let scopes = Set(arrayLiteral: "admin_read")
	
	public let connector: HappnConnector
	
	public let userKey: String
	
	public private(set) var result = Result<HappnUser, Error>.failure(OperationIsNotFinishedError())
	
	/** `userKey` is the persistent id of the user. */
	public init(userKey k: String, connector c: HappnConnector) {
		userKey = k
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		guard
			let url = URL(string: userKey, relativeTo: URL(string: "api/users/", relativeTo: connector.baseURL)!),
			var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
		else {
			result = .failure(InternalError(message: "Cannot build URL to get happn user with key \(userKey)"))
			return baseOperationEnded()
		}
		urlComponents.queryItems = [
			URLQueryItem(name: "fields", value: "id,first_name,last_name,acl,login,nickname")
		]
		
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<HappnApiResult<HappnUser>>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			defer {self.baseOperationEnded()}
			
			guard let o = op.result.successValue else {
				self.result = .failure(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the user"]))
				return
			}
			guard o.success, let user = o.data else {
				self.result = .failure(NSError(domain: "com.happn.officectl.happn", code: o.error_code, userInfo: [NSLocalizedDescriptionKey: o.error ?? "Unknown error while fetching the user"]))
				return
			}
			
			self.result = .success(user)
		}
		op.start()
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
