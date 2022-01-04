/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/18.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import SemiSingleton
import URLRequestOperation

import OfficeModel



public final class ResetExternalServicePasswordAction : Action<TaggedID, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public typealias SemiSingletonKey = TaggedID
	public typealias SemiSingletonAdditionalInitInfo = (URL, ExternalServiceAuthenticator, JSONEncoder, JSONDecoder)
	
	public required init(key id: TaggedID, additionalInfo: SemiSingletonAdditionalInitInfo, store: SemiSingletonStore) {
		deps = Dependencies(serviceURL: additionalInfo.0, authenticator: additionalInfo.1, jsonEncoder: additionalInfo.2, jsonDecoder: additionalInfo.3)
		
		super.init(subject: id)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Swift.Error>) -> Void) throws {
		Task{await handler(Result{
			let op = try URLRequestDataOperation<ExternalServiceResponse<String>>.forAPIRequest(
				url: deps.serviceURL.appending("change-password"), httpBody: RequestBody(userID: subject, newPassword: newPassword),
				requestProcessors: [AuthRequestProcessor(deps.authenticator)], retryProviders: []
			)
			_ = try await op.startAndGetResult().result.asResult().get()
		})}
		
		struct RequestBody : Encodable {
			var userID: TaggedID
			var newPassword: String
		}
	}
	
	private struct Dependencies {
		
		let serviceURL: URL
		let authenticator: ExternalServiceAuthenticator
		
		let jsonEncoder: JSONEncoder
		let jsonDecoder: JSONDecoder
		
	}
	
	private let deps: Dependencies
	
}
