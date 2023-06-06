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
	
	public func connectIfNeeded() async throws {
		guard !isConnected else {
			return
		}
		
		try await connect(())
	}
	
	public nonisolated func urlRequestForEntryCGI<RequestBody : Encodable>(GETRequest request: RequestBody) throws -> URLRequest {
		return try urlRequest(for: "webapi/entry.cgi", GETRequest: request)
	}
	
	public nonisolated func urlRequest<RequestBody : Encodable>(for path: String, GETRequest request: RequestBody) throws -> URLRequest {
		var urlComponents = dsmURLComponents
		assert(urlComponents.percentEncodedQuery?.isEmpty ?? true)
		urlComponents.percentEncodedQuery = try FormURLEncodedEncoder().encode(request)
		if path.starts(with: "/") {urlComponents.path  = path}
		else                      {urlComponents.path += path}
		return try URLRequest(url: urlComponents.url ?! Err.internalError)
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_ scope: Void) async throws {
		try await unqueuedDisconnect()
		
		let request = TokenRequestBody(username: username, password: password)
		let op = try URLRequestDataOperation<ApiResponse<TokenResponseBody>>.forAPIRequest(
			urlRequest: urlRequestForEntryCGI(GETRequest: request),
			retryProviders: []
		)
		let apiErrorToError = [
			400: Err.apiLoginInvalidCreds,
			401: Err.apiLoginAccountDisabled,
			402: Err.apiLoginPermissionDenied,
			403: Err.apiLoginNeeds2FA,
			404: Err.apiLoginFailed2FA,
			406: Err.apiLoginEnforce2FA,
			407: Err.apiLoginForbiddenIP,
			408: Err.apiLoginExpiredPasswordAndCannotChange,
			409: Err.apiLoginExpiredPassword,
			410: Err.apiLoginPasswordMustBeChanged
		]
		let responseBody = try await op.startAndGetResult().result.get(apiErrorCodeToError: apiErrorToError)
		tokenInfo = TokenInfo(token: responseBody.sessionID)
	}
	
	public func unqueuedDisconnect() async throws {
		guard isConnected else {
			/* Nothing to do if we’re already disconnected. */
			return
		}
		
		let request = TokenRevokeRequestBody()
		let urlRequest = try await unqueuedAuthenticate(request: urlRequestForEntryCGI(GETRequest: request))
		let op = URLRequestDataOperation<ApiResponse<Empty>>.forAPIRequest(urlRequest: urlRequest)
		_ = try await op.startAndGetResult().result.get()
		tokenInfo = nil
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
