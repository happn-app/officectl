/*
 * GetHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/30.
 */

import Foundation

import HasResult
import RetryingOperation
import URLRequestOperation



public final class GetHappnUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = HappnUser
	
	public static let scopes = Set(arrayLiteral: "admin_read")
	
	public let connector: HappnConnector
	
	public let userKey: String
	
	public private(set) var result = Result<HappnUser, Error>.failure(OperationIsNotFinishedError())
	
	/** `userKey` is the persistent ID of the user. */
	public init(userKey k: String, connector c: HappnConnector) {
		userKey = k
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			result = await Result{
				let op = try URLRequestDataOperation<HappnApiResult<HappnUser>>.forAPIRequest(
					url: connector.baseURL.appending("api", "users", userKey), urlParameters: ["fields": "id,first_name,last_name,acl,login,nickname"],
					requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				let res = try await op.startAndGetResult().result
				guard res.success, let user = res.data else {
					throw NSError(domain: "com.happn.officectl.happn", code: res.error_code, userInfo: [NSLocalizedDescriptionKey: res.error ?? "Unknown error while fetching the user"])
				}
				return user
			}
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
