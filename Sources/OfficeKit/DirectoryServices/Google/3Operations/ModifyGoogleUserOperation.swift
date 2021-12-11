/*
 * ModifyGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/09/2018.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Email
import HasResult
import RetryingOperation
import URLRequestOperation



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
				let userId = user.persistentId.value ?? user.userId.rawValue
				let op = try URLRequestDataOperation<GoogleUser>.forAPIRequest(
					url: baseURL.appending("users", userId), method: "PUT", httpBody: user,
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
