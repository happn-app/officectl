/*
 * OAuthClientAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/29.
 */

import Foundation

import Vapor



struct OAuthClientAuthenticator : AsyncBasicAuthenticator {
	
	static let invalidClientError = Abort(.unauthorized, reason: "Client (auth app) does not exist or is inactive")
	
	func authenticate(basic: BasicAuthorization, for request: Request) async throws {
		guard let authApp = AuthApplication(rawValue: basic.username) else {
			throw Self.invalidClientError
		}
		
		guard authApp.matchesSecret(basic.password) else {
			throw Self.invalidClientError
		}
		
		request.auth.login(authApp)
	}
	
}
