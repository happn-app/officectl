/*
 * LogoutController.swift
 * officectl
 *
 * Created by François Lamboley on 28/02/2019.
 */

import Foundation

import JWTKit
import OfficeKit
import Vapor



class LogoutController {
	
	/** Logging out a given token. Note we don’t do anything here yet. In theory
	we should save the revoked token and verify token have not been explicitely
	revoked before allowing using them. As we have the “jti” claim in our tokens,
	we could in theory simply save this claim in the db if we ever want to
	implement proper token revocation. */
	func logout(_ req: Request) throws -> ApiResponse<String> {
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		_ = try JWTSigner.hs256(key: req.application.officectlConfig.jwtSecret).verify(bearer.token, as: ApiAuth.Token.self)
		
		return ApiResponse.data("ok")
	}
	
}
