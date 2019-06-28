/*
 * LogoutController.swift
 * officectl
 *
 * Created by François Lamboley on 28/02/2019.
 */

import Foundation

import JWT
import OfficeKit
import Vapor



#if false
class LogoutController {
	
	/** Logging out a given token. Note we don’t do anything here yet. In theory
	we should save the revoked token and verify token have not been explicitely
	revoked before allowing using them. As we have the “jti” claim in our tokens,
	we could in theory simply save this claim in the db if we ever want to
	implement proper token revocation. */
	func logout(_ req: Request) throws -> ApiResponse<String> {
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		_ = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: req.make(OfficectlConfig.self).jwtSecret))
		
		return ApiResponse.data("ok")
	}
	
}
#endif
