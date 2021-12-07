/*
 * DeleteHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/09/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import GenericJSON
import NIO
import RetryingOperation



public final class DeleteHappnUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = Void
	
	public static let scopes = Set(arrayLiteral: "admin_create"/* 😱🤷‍♂️ */, "admin_delete", "all_user_delete")
	
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
		/* A loop for conveniences */
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let userId = user.persistentId.value ?? user.userId ?? HappnConnector.nullLoginUserId
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		
		let f = eventLoop.makeSucceededFuture(())
			.flatMapThrowing{ _ -> AuthenticatedJSONOperation<HappnApiResult<Int8>> in
				guard case .userPass(_, let adminPass) = self.connector.authMode else {
					throw InvalidArgumentError(message: "Cannot delete a user without the password of the admin")
				}
				
				var urlRequest = URLRequest(url: URL(string: "api/administrators/", relativeTo: self.connector.baseURL)!)
				urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				do {
					/* Let’s build the request content */
					var urlComponents = URLComponents()
					urlComponents.queryItems = [
						URLQueryItem(name: "_action", value: "revoke"),
						URLQueryItem(name: "user_id", value: userId),
						URLQueryItem(name: "password", value: adminPass)
					]
					guard let qstr = urlComponents.percentEncodedQuery else {
						throw NSError(domain: "com.happn.officectl.happn", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot build url component to delete admin"])
					}
					urlRequest.httpBody = Data(qstr.utf8)
				}
				urlRequest.httpMethod = "POST"
				
				/* We declare a decoded type HappnApiResult<Int8>.
				 * We chose Int8, but could have taken anything that’s decodable: the API returns null all the time… */
				return AuthenticatedJSONOperation<HappnApiResult<Int8>>(request: urlRequest, authenticator: self.connector.authenticate, decoder: decoder)
			}.flatMap{
				return EventLoopFuture<HappnApiResult<Int8>>.future(from: $0, on: eventLoop).flatMapThrowing{
					guard $0.success else {
						throw NSError(domain: "com.happn.officectl.happn", code: $0.error_code, userInfo: [NSLocalizedDescriptionKey: $0.error ?? "Unknown error while revoking user admin access"])
					}
				}
			}
			.flatMap{ _ -> EventLoopFuture<Void> in
				do {
					guard
						let url = URL(string: userId, relativeTo: URL(string: "api/users/", relativeTo: self.connector.baseURL)!),
						var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
					else {
						throw InternalError(message: "Cannot build URL to get happn user with key \(userId)")
					}
					urlComponents.queryItems = [
						URLQueryItem(name: "to_delete", value: "true")
					]
					var urlRequest = URLRequest(url: urlComponents.url!)
					urlRequest.httpMethod = "DELETE"
					
					let op = AuthenticatedJSONOperation<HappnApiResult<Int8>>(request: urlRequest, authenticator: self.connector.authenticate, decoder: decoder)
					return EventLoopFuture<Void>.future(from: op, on: eventLoop, resultRetriever: { _ in /* We don’t care about the error if any. */ })
				} catch {
					/* We don’t care about the error here… */
					return eventLoop.makeSucceededFuture(())
				}
			}
		
		f.whenComplete{ r in
			self.error = r.failureValue
			self.baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
