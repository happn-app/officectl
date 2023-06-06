/*
 * SynologyConnector.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import FormURLEncodedCoder
import OperationAwaiting
import TaskQueue
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit



public actor SynologyConnector : Connector, Authenticator, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Void
	
	public let dsmURLComponents: URLComponents
	public var username: String
	public var password: String
	
	public var isConnected: Bool    {tokenInfo != nil}
	public var accessToken: String? {tokenInfo?.token}
	
	public init(dsmURL: URL, username: String, password: String) throws {
		try self.init(
			dsmURLComponents: URLComponents(url: dsmURL, resolvingAgainstBaseURL: true) ?! Err.dsmURLIsInvalid,
			username: username,
			password: password
		)
	}
	
	public init(dsmURLComponents: URLComponents, username: String, password: String) throws {
		guard dsmURLComponents.percentEncodedQuery?.isEmpty ?? true else {
			throw Err.dsmURLIsInvalid
		}
		var dsmURLComponents = dsmURLComponents
		/* If the DSM URL have an empty path, we replace by / to avoid further issues. */
		if dsmURLComponents.path.isEmpty {
			dsmURLComponents.path = "/"
		}
		
		self.dsmURLComponents = dsmURLComponents
		self.username = username
		self.password = password
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_ scope: Void) async throws {
		try await unqueuedDisconnect()
		
		let request = TokenRequestBody(username: username, password: password)
		var urlComponents = dsmURLComponents
		assert(urlComponents.percentEncodedQuery?.isEmpty ?? true)
		urlComponents.percentEncodedQuery = try FormURLEncodedEncoder().encode(request)
		urlComponents.path += "webapi/entry.cgi"
		
		let url = try urlComponents.url ?! Err.internalError
		let op = URLRequestDataOperation<ApiResponse<TokenResponseBody>>.forAPIRequest(url: url, retryProviders: [])
		let res = try await op.startAndGetResult().result
		switch res {
			case let .success(body):
				tokenInfo = TokenInfo(token: body.sessionID)
				
			case let .failure(error):
				switch error.code {
					case 400: throw Err.loginInvalidCreds
					case 401: throw Err.loginAccountDisabled
					case 402: throw Err.permissionDenied
					case 403: throw Err.loginNeeds2FA
					case 404: throw Err.loginFailed2FA
					case 406: throw Err.loginEnforce2FA
					case 407: throw Err.loginForbiddenIP
					case 408: throw Err.loginExpiredPasswordAndCannotChange
					case 409: throw Err.loginExpiredPassword
					case 410: throw Err.loginPasswordMustBeChanged
					default: throw Err.unknownCode(error.code)
				}
		}
	}
	
	public func unqueuedDisconnect() async throws {
		guard isConnected else {
			/* Nothing to do if we’re already disconnected. */
			return
		}
		
		let request = TokenRevokeRequestBody()
		var urlComponents = dsmURLComponents
		assert(urlComponents.percentEncodedQuery?.isEmpty ?? true)
		urlComponents.percentEncodedQuery = try FormURLEncodedEncoder().encode(request)
		urlComponents.path += "webapi/entry.cgi"
		
		let urlRequest = try await unqueuedAuthenticate(request: URLRequest(url: urlComponents.url ?! Err.internalError))
		let op = URLRequestDataOperation<ApiResponse<Empty>>.forAPIRequest(urlRequest: urlRequest)
		let res = try await op.startAndGetResult().result
		
		switch res {
			case .success: tokenInfo = nil
			case .failure(let err): throw Err.unknownCode(err.code)
		}
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* Make sure we're connected. */
		guard let tokenInfo else {
			throw Err.notConnected
		}
		
		/* If there are no URL in the request, we have nothing to do. */
		guard let url = request.url else {
			return request
		}
		
		/* Read the URL components of the URLRequest. */
		var components = try URLComponents(url: url, resolvingAgainstBaseURL: true) ?! Err.internalError
		/* We do not care whether there is an _sid parameter already or not. */
		components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "_sid", value: tokenInfo.token)]
		
		var request = request
		request.url = try components.url ?! Err.internalError
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	/* We only use this variable to avoid a double-refresh of the access token. */
	private var authInfoChangeDate = Date.distantPast
	private var tokenInfo: TokenInfo? {
		didSet {authInfoChangeDate = Date()}
	}
	
	private struct TokenInfo : Sendable, Codable {
		
		var token: String
		
	}
	
}
