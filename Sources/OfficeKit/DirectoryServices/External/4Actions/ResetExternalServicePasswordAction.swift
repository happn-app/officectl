/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import SemiSingleton
import Service



public class ResetExternalServicePasswordAction : Action<TaggedId, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public typealias SemiSingletonKey = TaggedId
	public typealias SemiSingletonAdditionalInitInfo = (URL, ExternalServiceAuthenticator, JSONEncoder, JSONDecoder)
	
	public required init(key id: TaggedId, additionalInfo: SemiSingletonAdditionalInitInfo, store: SemiSingletonStore) {
		deps = Dependencies(serviceURL: additionalInfo.0, authenticator: additionalInfo.1, jsonEncoder: additionalInfo.2, jsonDecoder: additionalInfo.3)
		
		super.init(subject: id)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Swift.Error>) -> Void) throws {
		guard let url = URL(string: "change-password", relativeTo: deps.serviceURL) else {
			throw InternalError(message: "Cannot get external service URL to update the password of a user")
		}
		
		struct Request : Encodable {
			var userId: TaggedId
			var newPassword: String
		}
		let request = Request(userId: subject, newPassword: newPassword)
		let requestData = try deps.jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = AuthenticatedJSONOperation<ExternalServiceResponse<String>>(request: urlRequest, authenticator: deps.authenticator.authenticate, decoder: deps.jsonDecoder)
		operation.completionBlock = {
			let r = operation.result.flatMap{ $0.asResult().map{ _ in () }.mapError{ $0 as Error } }
			handler(r)
		}
		defaultOperationQueueForFutureSupport.addOperation(operation)
	}
	
	private struct Dependencies {
		
		let serviceURL: URL
		let authenticator: ExternalServiceAuthenticator
		
		let jsonEncoder: JSONEncoder
		let jsonDecoder: JSONDecoder
		
	}
	
	private let deps: Dependencies
	
}
