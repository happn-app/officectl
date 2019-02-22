/*
 * LoginController.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import OfficeKit
import Vapor



class LoginController {
	
	func login(_ req: Request) throws -> Future<ApiResponse<ApiAuth>> {
		let loginData = try req.content.syncDecode(LoginData.self)
		let user = User(id: .distinguishedName(loginData.username))
		
		return try user
		.checkLDAPPassword(container: req, checkedPassword: loginData.password)
		.map{
			/* The password of the user is verified. Let’s return the relevant data */
			#warning("todo")
			return .data(ApiAuth(token: "toto", expirationDate: Date(timeIntervalSinceNow: 30), isAdmin: false))
		}
	}
	
	private struct LoginData : Decodable {
		
		var username: LDAPDistinguishedName
		var password: String
		
	}
	
}
