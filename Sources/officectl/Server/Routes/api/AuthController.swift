/*
 * UserSessionAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/30.
 */

import Foundation

import JWT
import UnwrapOrThrow
import Vapor

import OfficeKit
import OfficeModel



class AuthController {
	
	func token(_ req: Request) async throws -> ApiTokenResponse {
//		let invalidCredsError = Abort(.unauthorized, reason: "Invalid username or password.")
		
		guard req.headers.contentType == .urlEncodedForm else {
			/* Specs requires content-type to be URL Encoded Form.
			 * If we do not care, simply remove this guard.
			 * Note: A new RFC allows JSON body (RFC 8259). */
			throw Abort(.unsupportedMediaType, reason: "OAuth2 framework (RFC 6749) requires requests data to be URL Encoded Form.")
		}
		
		let partialGrantRequest = try req.content.decode(_PartialApiAuthGrantRequest.self)
		
		let authScopes: Set<AuthScope> = try Set(
			partialGrantRequest.scope?
				.split(separator: " ")
				.map{ try AuthScope(rawValue: String($0)) ?! Abort(.badRequest, reason: "Invalid scopes") }
			?? []
		)
		let authApp = try await req.auth.requireAuthApp(clientIDInBody: partialGrantRequest.clientID, clientSecretInBody: partialGrantRequest.clientSecret, logger: req.logger)
		
		let appAuthorizedScopes = authApp.authorizedScopes
		
		let sProvider = req.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		
		switch partialGrantRequest.grantType {
			case "password":
				let grantRequest = try req.content.decode(ApiAuthPasswordGrantRequest.self)
				
				let userPair = try AnyDSUIDPair(taggedID: grantRequest.username, servicesProvider: sProvider).dsuPair()
				guard userPair.service.config.serviceID == authService.config.serviceID else {
					throw Abort(.unauthorized, reason: "Tried to login with an ID which is not from the auth service (expected \(authService.config.serviceID)).")
				}
				guard try await authService.authenticate(userID: userPair.user.userID, challenge: grantRequest.password, using: req.services) else {
					throw Abort(.unauthorized, reason: "Invalid credentials. Please check your username and password.")
				}
				
				let isAdmin = try await authService.validateAdminStatus(userID: userPair.user.userID, using: req.services)
				let loggedInUser = LoggedInUser(user: userPair, scopes: (isAdmin ? authScopes : authScopes.subtracting(Set(arrayLiteral: .admin))).intersection(appAuthorizedScopes))
				
				/* Create the AuthToken from the userID */
				let token = AuthToken(dsuIDPair: loggedInUser.user.dsuIDPair, clientID: authApp.rawValue, expirationTime: 30*60/* 30 minutes */, scope: loggedInUser.scopes)
				let signedToken = try req.application.jwt.signers.sign(token, typ: "at+jwt", kid: req.application.jwt.keyName)
				return try ApiTokenResponse(userID: token.sub.rawValue, accessToken: signedToken, tokenType: "bearer", scope: token.authScopes, expiresIn: token.exp.value.timeIntervalSinceNow, refreshToken: nil)
				
			default:
				throw Abort(.unauthorized, reason: "Unsupported grant type.")
		}
	}
	
	/* We do not fail to revoke an invalid token: https://datatracker.ietf.org/doc/html/rfc7009#section-2.2. */
	func tokenRevoke(req: Request) async throws -> String {
		guard req.headers.contentType == .urlEncodedForm else {
			/* Specs requires content-type to be URL Encoded Form.
			 * If we do not care, simply remove this guard.
			 * Note: A new RFC allows JSON body (RFC 8259). */
			throw Abort(.unsupportedMediaType, reason: "OAuth2 framework (RFC 6749) requires token revocation data to be URL Encoded Form.")
		}
		
		let postData = try req.content.decode(ApiAuthTokenRevokeRequest.self)
		let authApp = try await req.auth.requireAuthApp(clientIDInBody: postData.clientID, clientSecretInBody: postData.clientSecret, logger: req.logger)
		
		let tokenType = postData.tokenTypeHint ?? inferTokenType(from: postData.token)
		switch tokenType {
			case .accessToken:
				/* We do not revoke JWT tokens (yet anyway, we have jti if we want to do it later), so there’s nothing to do… */
				if let jwt = try? req.jwt.verify(postData.token, as: AuthToken.self) {
					/* … but we still verify the JWT is issued from the same app that is auth’d.
					 * Later we might be able to create apps whose scope is to revoke tokens from other apps, but for now this hasn’t been done. */
					guard authApp.rawValue == jwt.clientID else {
						throw Abort(.unauthorized, reason: "Cannot revoke a token from another client.")
					}
				}
				
			case .refreshToken:
				throw Abort(.internalServerError, reason: "TODO")
		}
		
		return "ok"
	}
	
	private func inferTokenType(from token: String) -> ApiAuthTokenRevokeRequest.TokenType {
		/* Refresh tokens simply have a common prefix.
		 * If the prefix is not there, we must have an access token (JWT).
		 * Full token validation is done later anyway. */
		return .accessToken
//		return token.hasPrefix(DbAuthRefreshToken.tokenPrefix) ? .refreshToken : .accessToken
	}
	
}
