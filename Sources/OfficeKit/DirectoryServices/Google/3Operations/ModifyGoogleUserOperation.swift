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

import RetryingOperation



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
		do {
			let dataToSend = try JSONEncoder().encode(user)
			
			let userId = user.persistentId.value ?? user.userId.rawValue
			let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/users/")!
			guard let url = URL(string: userId, relativeTo: baseURL), let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
				throw InternalError(message: "Cannot build URL to modify Google user \(user)")
			}
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = dataToSend
			urlRequest.httpMethod = "PUT"
			
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .customISO8601
			decoder.keyDecodingStrategy = .useDefaultKeys
			let op = AuthenticatedJSONOperation<GoogleUser>(request: urlRequest, authenticator: connector.authenticate, decoder: decoder)
			op.completionBlock = {
				guard op.result.successValue != nil else {
					self.error = op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the user"])
					self.baseOperationEnded()
					return
				}
				
				self.error = nil
				self.baseOperationEnded()
			}
			op.start()
		} catch let err {
			error = err
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
