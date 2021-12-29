/*
 * CreateHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/02.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import HasResult
import NIO
import RetryingOperation
import URLRequestOperation



public final class CreateHappnUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = HappnUser
	
	public static let scopes = Set(arrayLiteral: "admin_create", "user_create")
	
	public let connector: HappnConnector
	
	public let user: HappnUser
	public private(set) var result = Result<HappnUser, Error>.failure(OperationIsNotFinishedError())
	
	public init(user u: HappnUser, connector c: HappnConnector) {
		user = u
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			result = await Result{
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				decoder.keyDecodingStrategy = .useDefaultKeys
				
				guard case .userPass(_, let adminPass) = connector.authMode else {
					throw InvalidArgumentError(message: "Cannot create an admin user without the password of the admin creating the account (non user/pass connectors are not supported)")
				}
				
				guard user.password.value != nil else {
					throw InvalidArgumentError(message: "A user must be created w/ a password (or we get a weird error when creating the account, and the account is unusable though it appear to exist)")
				}
				
				/* 1. Create the user. */
				
				let createUserOperation = try URLRequestDataOperation<HappnApiResult<HappnUser>>.forAPIRequest(
					url: connector.baseURL.appending("api", "users"),
					urlParameters: ["fields": "id,first_name,last_name,acl,login,nickname"], httpBody: user,
					decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				var urlComponentsUserCreation = URLComponents(url: URL(string: "api/users/", relativeTo: connector.baseURL)!, resolvingAgainstBaseURL: true)!
				urlComponentsUserCreation.queryItems = [
					URLQueryItem(name: "fields", value: "id,first_name,last_name,acl,login,nickname")
				]
				/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
				let apiUserResult = try await createUserOperation.startAndGetResult().result
				guard apiUserResult.success, let user = apiUserResult.data, let userId = user.id.value else {
					throw NSError(domain: "com.happn.officectl.happn", code: apiUserResult.error_code, userInfo: [NSLocalizedDescriptionKey: apiUserResult.error ?? "Unknown error while creating the user"])
				}
				
				/* 2. Make it an admin. */
				
				/* We declare a decoded type HappnApiResult<Int8>.
				 * We chose Int8, but could have taken anything that’s decodable: the API returns null all the time… */
				let makeUserAdminOperation = try URLRequestDataOperation<HappnApiResult<Int8>>.forAPIRequest(
					url: connector.baseURL.appending("api", "administrators"), httpBody: GrantRequestBody(userId: userId, adminPassword: adminPass),
					decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
				let apiGrantResult = try await makeUserAdminOperation.startAndGetResult().result
				guard apiGrantResult.success else {
					throw NSError(domain: "com.happn.officectl.happn", code: apiGrantResult.error_code, userInfo: [NSLocalizedDescriptionKey: apiGrantResult.error ?? "Unknown error while granting user admin access"])
				}
				
				/* 3. Set the ACLs. */
				// POST /api/user-acls
				// Data: x-www-form-urlencoded
				//    - permissions: ...
				//    - user_id: ...
				// Response: null (in a standard response)
				
				return user
			}
			baseOperationEnded()
		}
		
		/* ***** */
		
		struct GrantRequestBody : Encodable {
			var action = "grant"
			var userId: String
			var adminPassword: String
			private enum CodingKeys : String, CodingKey {
				case action = "_action", userId = "user_id", adminPassword = "password"
			}
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
