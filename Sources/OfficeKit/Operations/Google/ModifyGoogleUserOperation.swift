/*
 * ModifyGoogleUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/09/2018.
 */

import Foundation

import RetryingOperation



/* https://developers.google.com/admin-sdk/directory/v1/reference/users/update */
public class ModifyGoogleUserOperation : RetryingOperation {
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user")
	
	public let connector: GoogleJWTConnector
	
	public let user: GoogleUser
	public let propertiesToUpdate: Set<String>
	public private(set) var error: Error? = OperationIsNotFinishedError()
	
	public init(user u: GoogleUser, propertiesToUpdate ps: Set<String>, connector c: GoogleJWTConnector) {
		user = u
		connector = c
		propertiesToUpdate = ps
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		do {
			/* Not elegant, but I don’t have a better idea right now… (There is the
			 * start of an alternative commented at the end of the method, but this
			 * does not seem viable.) */
			let jsonEncoder = JSONEncoder()
			let jsonData = try jsonEncoder.encode(user)
			guard let userDictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
				throw InternalError()
			}
			let toSend = userDictionary.filter{ propertiesToUpdate.contains($0.key) }
			let dataToSend = try JSONSerialization.data(withJSONObject: toSend, options: [])
			
			let urlComponents = URLComponents(url: URL(string: user.id, relativeTo: URL(string: "https://www.googleapis.com/admin/directory/v1/users/")!)!, resolvingAgainstBaseURL: true)!
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = dataToSend
			urlRequest.httpMethod = "PUT"
			
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .customISO8601
			#if !os(Linux)
				decoder.keyDecodingStrategy = .useDefaultKeys
			#endif
			let op = AuthenticatedJSONOperation<GoogleUser>(request: urlRequest, authenticator: connector.authenticate, decoder: decoder)
			op.completionBlock = {
				guard op.decodedObject != nil else {
					self.error = op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the user"])
					self.baseOperationEnded()
					return
				}
				
				self.baseOperationEnded()
			}
			op.start()
			
			/*var propertiesToSend = [String: Any]()
			Mirror(reflecting: user).children.forEach{
				guard let l = $0.label, propertiesToUpdate.contains(l) else {return}
				propertiesToSend[l] = $0.value
			}
			print(propertiesToSend)*/
		} catch let err {
			baseOperationEnded()
			error = err
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}