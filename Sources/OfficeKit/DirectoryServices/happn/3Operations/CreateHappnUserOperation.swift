/*
 * CreateHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/09/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import NIO
import RetryingOperation



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
		/* A loop for conveniences */
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		
		let f = eventLoop.future()
		.flatMap{ _ -> EventLoopFuture<(apiUserResult: HappnApiResult<HappnUser>, adminPass: String)> in
			guard case .userPass(_, let adminPass) = self.connector.authMode else {
				throw InvalidArgumentError(message: "Cannot create an admin user without the password of the admin creating the account (non user/pass connectors are not supported)")
			}
			
			var urlComponents = URLComponents(url: URL(string: "api/users/", relativeTo: self.connector.baseURL)!, resolvingAgainstBaseURL: true)!
			urlComponents.queryItems = [
				URLQueryItem(name: "fields", value: "id,first_name,last_name,acl,login,nickname")
			]
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = try JSONEncoder().encode(self.user)
			urlRequest.httpMethod = "POST"
			
			let op = AuthenticatedJSONOperation<HappnApiResult<HappnUser>>(request: urlRequest, authenticator: self.connector.authenticate, decoder: decoder)
			return EventLoopFuture<HappnApiResult<HappnUser>>.future(from: op, eventLoop: eventLoop).map{ ($0, adminPass) }
		}
		.map{ (r: (apiUserResult: HappnApiResult<HappnUser>, adminPass: String)) -> (user: HappnUser, userId: String, adminPass: String) in
			guard r.apiUserResult.success, let user = r.apiUserResult.data, let userId = user.id.value else {
				throw NSError(domain: "com.happn.officectl.happn", code: r.apiUserResult.error_code, userInfo: [NSLocalizedDescriptionKey: r.apiUserResult.error ?? "Unknown error while creating the user"])
			}
			return (user, userId, r.adminPass)
		}
		.flatMap{ (r: (user: HappnUser, userId: String, adminPass: String)) -> EventLoopFuture<(apiGrantResult: HappnApiResult<Int8>, user: HappnUser)> in
			var components = URLComponents()
			components.queryItems = [
				URLQueryItem(name: "_action",  value: "grant"),
				URLQueryItem(name: "user_id",  value: r.userId),
				URLQueryItem(name: "password", value: r.adminPass)
			]
			
			var urlRequest = URLRequest(url: URL(string: "api/administrators/", relativeTo: self.connector.baseURL)!)
			urlRequest.httpBody = components.percentEncodedQuery.flatMap{ Data($0.utf8) }
			urlRequest.httpMethod = "POST"
			
			/* We declare a decoded type HappnApiResult<Int8>. We chose Int8,
			 * but could have taken anything that’s decodable: the API returns
			 * null all the time… */
			let op = AuthenticatedJSONOperation<HappnApiResult<Int8>>(request: urlRequest, authenticator: self.connector.authenticate, decoder: decoder)
			return EventLoopFuture<HappnApiResult<Int8>>.future(from: op, eventLoop: eventLoop).map{ ($0, r.user) }
		}
		.map{ (r: (apiGrantResult: HappnApiResult<Int8>, user: HappnUser)) -> Void in
			guard r.apiGrantResult.success else {
				throw NSError(domain: "com.happn.officectl.happn", code: r.apiGrantResult.error_code, userInfo: [NSLocalizedDescriptionKey: r.apiGrantResult.error ?? "Unknown error while granting user admin access"])
			}
			self.result = .success(r.user)
		}
		// 3. To set the ACLs
		// POST /api/user-acls
		// Data: x-www-form-urlencoded
		//    - permissions: ...
		//    - user_id: ...
		// Response: null (in a standard response)
		
		f.whenFailure{ error in self.result = .failure(error) }
		f.whenComplete(baseOperationEnded)
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
