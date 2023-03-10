/*
 * GitHubConnector.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/28.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import JWT
import OperationAwaiting
import TaskQueue
import URLRequestOperation

import OfficeKit



public actor GitHubConnector : Connector, Authenticator, HTTPAuthConnector, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Void
	
	public static let apiURL = URL(string: "https://api.github.com")!
	
	public let appID: String
	public let installationID: String
	public let privateKey: RSAKey
	
	public var isConnected: Bool    {tokenInfo != nil}
	public var accessToken: String? {tokenInfo?.token}
	
	public init(appID: String, installationID: String, privateKeyURL: URL) throws {
		self.appID = appID
		self.installationID = installationID
		self.privateKey = try RSAKey.private(pem: Data(contentsOf: privateKeyURL))
	}
	
	public func connectIfNeeded() async throws {
		guard !isConnected else {
			return
		}
		
		try await connect(())
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_ auth: Void) async throws {
		try await unqueuedDisconnect()
		
		/* GitHub does not support non-int exp or iat. */
		let roundedNow = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded())
		let jwtPayload = TokenInstallOwnerProofPayload(iss: .init(value: appID), iat: .init(value: roundedNow), exp: .init(value: roundedNow + 30))
		let jwtToken = try JWTSigner.rs256(key: privateKey).sign(jwtPayload)
		
		let decoder = SendableJSONDecoder{
			$0.dateDecodingStrategy = .iso8601
		}
		let accessTokenURL = try Self.apiURL.appendingPathComponentsSafely("app", "installations", installationID, "access_tokens")
		let tokenResponse = try await URLRequestDataOperation<TokenResponseBody>
			.forAPIRequest(url: accessTokenURL, method: "POST", headers: ["authorization": "Bearer \(jwtToken)"], decoders: [decoder], retryProviders: [])
			.startAndGetResult().result
		
		tokenInfo = TokenInfo(token: tokenResponse.token, expirationDate: tokenResponse.expiresAt)
	}
	
	public func unqueuedDisconnect() async throws {
		/* We do nothing (apart from removing the token from memory).
		 * The tokens we get from a connection operation are very short-lived.
		 * AFAIK there are no possible way to explicitly revoke an installation token. */
		tokenInfo = nil
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		if let tokenInfo, tokenInfo.expirationDate < Date() + TimeInterval(30) {
			/* If the token expires soon, we reauth it.
			 * Clients should retry requests failing for expired token reasons, but let’s be proactive and allow a useless call.
			 * We do not fail if the token refresh fails; our current token might still be valid.
			 *
			 * If the access token has _already_ expired, we do have to wait for the end of the refresh token step.
			 * If it has not, we could spawn the refresh in the background and continue on our merry way.
			 * We do not do this currently (TODO?): we wait whether the refresh was required or not.
			 *
			 * “-TimeInterval(45)”: "Rate-limiting" of the refresh of the token from request authentication to 1 per 45 seconds.
			 * This avoids refreshing the token for each requests if the access token expires less than 45s after it is created. */
			_ = try? await unqueuedRefreshToken(requestAuthDate: Date() - TimeInterval(45))
		}
		
		/* Make sure we're connected (_after_ potentially modifying the tokenInfo). */
		guard let tokenInfo else {
			throw Err.notConnected
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("Bearer \(tokenInfo.token)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	/* ****************************************
	   MARK: - HTTP Auth Connector (Retry Auth)
	   **************************************** */
	
	public func refreshToken(requestAuthDate: Date?) async throws {
		try await executeOnTaskQueue{ try await self.unqueuedRefreshToken(requestAuthDate: requestAuthDate) }
	}
	
	private func unqueuedRefreshToken(requestAuthDate: Date?) async throws {
		guard tokenInfo != nil else {
			throw Err.notConnected
		}
		guard (requestAuthDate ?? .distantFuture) > authInfoChangeDate else {
			/* The access auth has been changed _after_ the request was authenticated; we do not refresh the token (would probably be a double-refresh). */
			return
		}
		try await unqueuedConnect(())
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
		var expirationDate: Date
		
	}
	
}
