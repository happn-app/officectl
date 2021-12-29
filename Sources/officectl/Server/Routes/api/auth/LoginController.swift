/*
 * LoginController.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import JWT
import UnwrapOrThrow
import Vapor

import OfficeKit
import OfficeModel



class LoginController {
	
	func login(_ req: Request) async throws -> ApiTokenResponse {
		let invalidCredsError = Abort(.unauthorized, reason: "Invalid username or password.")
		
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
		let authApp = try await req.auth.requireAuthApp(clientIdInBody: partialGrantRequest.clientId, clientSecretInBody: partialGrantRequest.clientSecret, logger: req.logger)
		
		let appAuthorizedScopes = authApp.authorizedScopes
		
		let sProvider = req.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		
		switch partialGrantRequest.grantType {
			case "password":
				let grantRequest = try req.content.decode(ApiAuthPasswordGrantRequest.self)
				
				let userPair = try AnyDSUIdPair(taggedId: grantRequest.username, servicesProvider: sProvider).dsuPair()
				guard userPair.service.config.serviceId == authService.config.serviceId else {
					throw Abort(.unauthorized, reason: "Tried to login with an id which is not from the auth service (expected \(authService.config.serviceId)).")
				}
				guard try await authService.authenticate(userId: userPair.user.userId, challenge: grantRequest.password, using: req.services) else {
					throw Abort(.unauthorized, reason: "Invalid credentials. Please check your username and password.")
				}
				
				let isAdmin = try await authService.validateAdminStatus(userId: userPair.user.userId, using: req.services)
				let loggedInUser = LoggedInUser(user: userPair, scopes: isAdmin ? authScopes : authScopes.subtracting(Set(arrayLiteral: .admin)))
				
				/* Create the AuthToken from the userID */
				let token = AuthToken(dsuIdPair: loggedInUser.user.dsuIdPair, clientID: authApp.rawValue, expirationTime: 30*60/* 30 minutes */, scope: loggedInUser.scopes)
				let signedToken = try req.application.jwt.signers.sign(token, typ: "at+jwt", kid: req.application.jwt.keyName)
				return ApiTokenResponse(userId: token.sub.rawValue, accessToken: signedToken, tokenType: "bearer", scope: token.authScopes, expiresIn: token.exp.value.timeIntervalSinceNow, refreshToken: nil)
				
			default:
				throw Abort(.unauthorized, reason: "Unsupported grant type.")
		}
	}
	
}
