/*
 * GetGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/09/2018.
 */

import Foundation

import HasResult
import RetryingOperation
import URLRequestOperation



/* https://developers.google.com/admin-sdk/directory/v1/reference/users/get */
public final class GetGoogleUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = GoogleUser
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user")
	
	public let connector: GoogleJWTConnector
	
	public let userKey: String
	
	public private(set) var result = Result<GoogleUser, Error>.failure(OperationIsNotFinishedError())
	
	/**
	 Init the operation with the given user key.
	 A user key is either the Google id of the user or the email of the user. */
	public init(userKey k: String, connector c: GoogleJWTConnector) {
		userKey = k
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			result = await Result{
				let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
				
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				let op = URLRequestDataOperation<GoogleUser>.forAPIRequest(
					url: try baseURL.appending("users", userKey),
					decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				return try await op.startAndGetResult().result
			}
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
