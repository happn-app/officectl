/*
 * ModifyHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/01.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import HasResult
import RetryingOperation
import URLRequestOperation



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
		Task{
			error = await Result<Void, Error>{
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				decoder.keyDecodingStrategy = .useDefaultKeys
				let userID = user.persistentID ?? user.userID ?? HappnConnector.nullLoginUserID
				let op = try URLRequestDataOperation<HappnApiResult<HappnUser>>.forAPIRequest(
					url: connector.baseURL.appending("api", "users", userID), method: "PUT",
					urlParameters: ["fields": "id,first_name,last_name,acl,login,nickname"], httpBody: user,
					decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				let result = try await op.startAndGetResult().result
				guard result.success else {
					throw NSError(domain: "com.happn.officectl.happn", code: result.error_code, userInfo: [NSLocalizedDescriptionKey: result.error ?? "Unknown error while fetching the user"])
				}
			}.failureValue
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
