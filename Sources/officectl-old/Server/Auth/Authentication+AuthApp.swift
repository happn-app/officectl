/*
 * Authentication+AuthApp.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/29.
 */

import Foundation

import Vapor



extension Request.Authentication {
	
	func requireAuthApp(clientIDInBody: String?, clientSecretInBody: String?, logger: Logger) async throws -> AuthApplication {
		if let clientID = clientIDInBody {
			logger.warning("Including the client ID in the request’s body is supported but not recommended. Please use Basic Auth instead.")
			guard let authApp = AuthApplication(rawValue: clientID) else {
				throw OAuthClientAuthenticator.invalidClientError
			}
			guard authApp.matchesSecret(clientSecretInBody) else {
				throw OAuthClientAuthenticator.invalidClientError
			}
			let authed = get(AuthApplication.self)
			guard authed?.rawValue == authApp.rawValue || authed == nil else {
				throw Abort(.badRequest, reason: "Different client ID in client body and other source.")
			}
			login(authApp)
		} else {
			guard clientSecretInBody == nil else {
				throw Abort(.badRequest, reason: "If client_id is nil, client_secret must be nil too.")
			}
		}
		
		return try require(AuthApplication.self)
	}
	
}
