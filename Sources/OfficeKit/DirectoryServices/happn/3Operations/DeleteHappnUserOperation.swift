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
import HasResult
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
		Task{
			error = await Result<Void, Error>{
				let userId = user.persistentId.value ?? user.userId ?? HappnConnector.nullLoginUserId
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				decoder.keyDecodingStrategy = .useDefaultKeys
				
				guard case .userPass(_, let adminPass) = self.connector.authMode else {
					throw InvalidArgumentError(message: "Cannot delete a user without the password of the admin")
				}
				
				/* 1. Revoke user admin privileges. */
				
				var urlComponentsRevokeAdminContent = URLComponents()
				urlComponentsRevokeAdminContent.queryItems = [
					URLQueryItem(name: "_action", value: "revoke"),
					URLQueryItem(name: "user_id", value: userId),
					URLQueryItem(name: "password", value: adminPass)
				]
				guard let revokeAdminRequestContent = urlComponentsRevokeAdminContent.percentEncodedQuery else {
					throw NSError(domain: "com.happn.officectl.happn", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot build request content to revoke admin"])
				}
				var urlRequestRevokeAdmin = URLRequest(url: URL(string: "api/administrators/", relativeTo: self.connector.baseURL)!)
				urlRequestRevokeAdmin.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				urlRequestRevokeAdmin.httpBody = Data(revokeAdminRequestContent.utf8)
				urlRequestRevokeAdmin.httpMethod = "POST"
				
				/* We declare a decoded type HappnApiResult<Int8>.
				 * We chose Int8, but could have taken anything that’s decodable: the API returns null all the time… */
				let revokeAdminOp = AuthenticatedJSONOperation<HappnApiResult<Int8>>(request: urlRequestRevokeAdmin, authenticator: connector.authenticate, decoder: decoder)
				/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
				let revokeAdminResult = try await revokeAdminOp.startAndGetResult()
				guard revokeAdminResult.success else {
					throw NSError(domain: "com.happn.officectl.happn", code: revokeAdminResult.error_code, userInfo: [NSLocalizedDescriptionKey: revokeAdminResult.error ?? "Unknown error while revoking user admin access"])
				}
				
				/* 2. Delete the user. */
				
				guard
					let urlDeleteUser = URL(string: userId, relativeTo: URL(string: "api/users/", relativeTo: connector.baseURL)!),
					var urlComponentsDeleteUser = URLComponents(url: urlDeleteUser, resolvingAgainstBaseURL: true)
				else {
					throw InternalError(message: "Cannot build URL to delete happn user with key \(userId)")
				}
				urlComponentsDeleteUser.queryItems = [
					URLQueryItem(name: "to_delete", value: "true")
				]
				var urlRequestDeleteUser = URLRequest(url: urlComponentsDeleteUser.url!)
				urlRequestDeleteUser.httpMethod = "DELETE"
				
				let op = AuthenticatedJSONOperation<HappnApiResult<Int8>>(request: urlRequestDeleteUser, authenticator: connector.authenticate, decoder: decoder)
				/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
				await op.startAndWait() /* We don’t care about the error if any. */
			}.failureValue
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
