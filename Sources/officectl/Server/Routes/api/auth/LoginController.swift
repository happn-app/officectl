/*
 * LoginController.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import JWTKit
import OfficeKit
import Vapor



class LoginController {
	
	func login(_ req: Request) throws -> ApiResponse<ApiAuth> {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		let token = ApiAuth.Token(dsuIdPair: loggedInUser.user.dsuIdPair, admin: loggedInUser.isAdmin, validityDuration: 30*60) /* 30 minutes */
		let tokenString = try JWTSigner.hs256(key: req.application.officectlConfig.jwtSecret).sign(token)
		return .data(ApiAuth(token: tokenString, expirationDate: token.exp, isAdmin: token.adm))
	}
	
}
