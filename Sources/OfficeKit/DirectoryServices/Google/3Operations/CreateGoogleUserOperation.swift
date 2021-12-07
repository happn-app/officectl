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

import RetryingOperation



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
		do {
			let dataToSend = try JSONEncoder().encode(user)
			
			var urlRequest = URLRequest(url: URL(string: "https://www.googleapis.com/admin/directory/v1/users/")!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = dataToSend
			urlRequest.httpMethod = "POST"
			
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .customISO8601
			decoder.keyDecodingStrategy = .useDefaultKeys
			let op = AuthenticatedJSONOperation<GoogleUser>(request: urlRequest, authenticator: connector.authenticate, decoder: decoder)
			op.completionBlock = {
				guard let user = op.result.successValue else {
					self.result = .failure(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while creating the user"]))
					return self.baseOperationEnded()
				}
				
				self.result = .success(user)
				self.baseOperationEnded()
			}
			op.start()
		} catch let err {
			result = .failure(err)
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
