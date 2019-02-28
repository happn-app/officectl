/*
 * LoginController.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import JWT
import OfficeKit
import Vapor



class LoginController {
	
	func login(_ req: Request) throws -> Future<ApiResponse<ApiAuth>> {
		let loginData = try req.content.syncDecode(LoginData.self)
		let adminGroups = try req.make(OfficectlConfig.self).officeKitConfig.ldapConfigOrThrow().adminGroupsDN
		
		let dn = loginData.username
		let user = User(id: .distinguishedName(loginData.username))
		
		return try user
		.checkLDAPPassword(container: req, checkedPassword: loginData.password)
		.then{ _ -> Future<Bool> in
			do    {return try user.isMemberOf(anyGroup: adminGroups, container: req)}
			catch {return req.future(error: error)}
		}
		.map{ isAdmin in
			/* The password of the user is verified. Let’s return the relevant
			 * data. */
			let token = ApiAuth.Token(dn: dn, admin: isAdmin, validityDuration: 30*60) /* 30 minutes */
			guard let tokenString = String(data: try JWT(payload: token).sign(using: .hs256(key: "secret")), encoding: .utf8) else {
				throw Abort(.internalServerError)
			}
			
			return .data(ApiAuth(token: tokenString, expirationDate: token.exp, isAdmin: token.adm))
		}
	}
	
	private struct LoginData : Decodable {
		
		var username: LDAPDistinguishedName
		var password: String
		
	}
	
}
