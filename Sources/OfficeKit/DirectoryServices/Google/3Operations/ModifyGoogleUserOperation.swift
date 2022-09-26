/*
 * ModifyGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/12.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Email
import HasResult
import RetryingOperation
import URLRequestOperation



/* See https://github.com/happn-app/RetryingOperation/blob/123eafbc84db6b1bbcab6849882de2ccd1f6e60e/Sources/RetryingOperation/WrappedRetryingOperation.swift#L36
 *  for more info about the unchecked Sendable conformance. */
extension ModifyGoogleUserOperation : @unchecked Sendable {}

/* https://developers.google.com/admin-sdk/directory/v1/reference/users/update */
public final class ModifyGoogleUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = Void
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user")
	
	public let connector: GoogleJWTConnector
	
	public let user: GoogleUser
	public private(set) var error: Error? = OperationIsNotFinishedError()
	public var result: Result<Void, Error> {
		if let error = error {return .failure(error)}
		return .success(())
	}
	
	public init(user u: GoogleUser, connector c: GoogleJWTConnector) {
		user = u
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			error = await Result<Void, Error>{
				let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
				
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				decoder.keyDecodingStrategy = .useDefaultKeys
				let userID = user.persistentID ?? user.userID.rawValue
				let op = try URLRequestDataOperation<GoogleUser>.forAPIRequest(
					url: baseURL.appending("users", userID), method: "PUT", httpBody: user,
					decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				_ = try await op.startAndGetResult().result
			}.failureValue
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
