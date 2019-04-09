/*
 * ModifyGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/09/2018.
 */

import Foundation

import GenericJSON
import RetryingOperation



/* https://developers.google.com/admin-sdk/directory/v1/reference/users/update */
public class ModifyGoogleUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = Void
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user")
	
	public let connector: GoogleJWTConnector
	
	public let user: GoogleUser
	public let propertiesToUpdate: Set<String>
	public private(set) var error: Error? = OperationIsNotFinishedError()
	public func resultOrThrow() throws -> Void {
		try throwIfError(error)
		return ()
	}
	
	public init(user u: GoogleUser, propertiesToUpdate ps: Set<GoogleUser.CodingKeys>, connector c: GoogleJWTConnector) {
		user = u
		connector = c
		propertiesToUpdate = Set(ps.map{ $0.rawValue })
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		do {
			/* Not elegant, but I don’t have a better idea right now… (There is the
			 * start of an alternative commented at the end of the method, but this
			 * does not seem viable.) */
			let userJSON = try JSON(encodable: user).objectValue!
			let toSend = userJSON.filter{ propertiesToUpdate.contains($0.key) }
			let dataToSend = try JSONEncoder().encode(toSend)
			
			let urlComponents = URLComponents(url: URL(string: user.id, relativeTo: URL(string: "https://www.googleapis.com/admin/directory/v1/users/")!)!, resolvingAgainstBaseURL: true)!
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = dataToSend
			urlRequest.httpMethod = "PUT"
			
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .customISO8601
			decoder.keyDecodingStrategy = .useDefaultKeys
			let op = AuthenticatedJSONOperation<GoogleUser>(request: urlRequest, authenticator: connector.authenticate, decoder: decoder)
			op.completionBlock = {
				guard op.result != nil else {
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
