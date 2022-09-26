/*
 * DeleteHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/01.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import FormURLEncodedEncoding
import GenericJSON
import HasResult
import NIO
import RetryingOperation
import URLRequestOperation



/* See https://github.com/happn-app/RetryingOperation/blob/123eafbc84db6b1bbcab6849882de2ccd1f6e60e/Sources/RetryingOperation/WrappedRetryingOperation.swift#L36
 *  for more info about the unchecked Sendable conformance. */
extension DeleteHappnUserOperation : @unchecked Sendable {}

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
				let userID = user.persistentID ?? user.userID ?? HappnConnector.nullLoginUserID
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				
				guard case .userPass(_, let adminPass) = self.connector.authMode else {
					throw InvalidArgumentError(message: "Cannot delete a user without the password of the admin")
				}
				
				/* 1. Revoke user admin privileges. */
				
				/* We declare a decoded type HappnApiResult<Int8>.
				 * We chose Int8, but could have taken anything that’s decodable: the API returns null all the time… */
				let revokeOp = try URLRequestDataOperation<HappnApiResult<Int8>>.forAPIRequest(
					url: connector.baseURL.appending("api", "administrators"), httpBody: RevokeRequestBody(userID: userID, adminPassword: adminPass),
					bodyEncoder: FormURLEncodedEncoder(), decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
				_ = try await revokeOp.startAndGetResult()
				
				/* 2. Delete the user. */
				
				let deleteOp = try URLRequestDataOperation<HappnApiResult<Int8>>.forAPIRequest(
					url: connector.baseURL.appending("api", "users", userID), method: "DELETE", urlParameters: DeleteRequestQuery(),
					decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
				await deleteOp.startAndWait() /* We don’t care about the error if any. */
			}.failureValue
			baseOperationEnded()
		}
		
		/* ***** */
		
		struct RevokeRequestBody : Encodable {
			var action = "revoke"
			var userID: String
			var adminPassword: String
			private enum CodingKeys : String, CodingKey {
				case action = "_action", userID = "user_id", adminPassword = "password"
			}
		}
		
		struct DeleteRequestQuery : Encodable {
			var toDelete = "true"
			private enum CodingKeys : String, CodingKey {
				case toDelete = "to_delete"
			}
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
