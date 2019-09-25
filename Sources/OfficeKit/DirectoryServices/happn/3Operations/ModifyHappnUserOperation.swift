/*
 * ModifyHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/09/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import RetryingOperation



public final class ModifyHappnUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = Void
	
	public static let scopes = Set(arrayLiteral: "admin_read", "all_user_update")

	public let connector: HappnConnector
	
	public let user: HappnUser
	public private(set) var error: Error? = OperationIsNotFinishedError()
	public var result: Result<Void, Error> {
		if let error = error {return .failure(error)}
		return .success(())
	}
	
	public init(user u: HappnUser, connector c: HappnConnector) {
		user = u
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		do {
			let dataToSend = try JSONEncoder().encode(user)
			
			let userId = user.persistentId.value ?? user.userId ?? HappnConnector.nullLoginUserId
			let baseURL = URL(string: "api/users/", relativeTo: connector.baseURL)!
			guard let url = URL(string: userId, relativeTo: baseURL), var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
				throw InternalError(message: "Cannot build URL to modify happn user \(user)")
			}
			urlComponents.queryItems = [
				URLQueryItem(name: "fields", value: "id,first_name,last_name,acl,login,nickname")
			]
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = dataToSend
			urlRequest.httpMethod = "PUT"
			
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .customISO8601
			decoder.keyDecodingStrategy = .useDefaultKeys
			let op = AuthenticatedJSONOperation<HappnApiResult<HappnUser>>(request: urlRequest, authenticator: connector.authenticate, decoder: decoder)
			op.completionBlock = {
				defer {self.baseOperationEnded()}
				
				guard let o = op.result.successValue else {
					self.error = op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the user"])
					return
				}
				guard o.success else {
					self.error = NSError(domain: "com.happn.officectl.happn", code: o.error_code, userInfo: [NSLocalizedDescriptionKey: o.error ?? "Unknown error while fetching the user"])
					return
				}
				
				self.error = nil
			}
			op.start()
		} catch let err {
			error = err
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
