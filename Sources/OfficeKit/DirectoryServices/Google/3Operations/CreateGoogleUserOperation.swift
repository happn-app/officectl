/*
 * CreateGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import HasResult
import RetryingOperation
import URLRequestOperation



/* https://developers.google.com/admin-sdk/directory/v1/reference/users/insert */
public final class CreateGoogleUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = GoogleUser
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user")
	
	public let connector: GoogleJWTConnector
	
	public let user: GoogleUser
	public private(set) var result = Result<GoogleUser, Error>.failure(OperationIsNotFinishedError())
	
	public init(user u: GoogleUser, connector c: GoogleJWTConnector) {
		user = u
		connector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			result = await Result{
				let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
				
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				decoder.keyDecodingStrategy = .useDefaultKeys
				let op = try URLRequestDataOperation<GoogleUser>.forAPIRequest(
					url: baseURL.appending("users"), httpBody: user,
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
