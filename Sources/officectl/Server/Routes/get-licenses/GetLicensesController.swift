/*
 * GetLicensesController.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/7.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import OfficeKit
import URLRequestOperation
import Vapor



class GetLicensesController {
	
	func showLogin(_ req: Request) throws -> EventLoopFuture<View> {
		return req.view.render("GetLicensesLogin")
	}
	
	func getLicenses(_ req: Request) throws -> EventLoopFuture<View> {
		struct GetLicensesData : Decodable {
			
			var email: Email
			var password: String
			
		}
		
		let getLicensesData = try req.content.decode(GetLicensesData.self)
		let officeKitServiceProvider = req.application.officeKitServiceProvider
		let authService = try officeKitServiceProvider.getDirectoryAuthenticatorService()
		let user = try authService.logicalUser(fromEmail: getLicensesData.email, servicesProvider: officeKitServiceProvider)
		
		let officectlConfig = req.application.officectlConfig
		let token = try nil2throw(officectlConfig.tmpSimpleMDMToken)
		
		let username = getLicensesData.email.username
		
		return try authService.authenticate(userId: user.userId, challenge: getLicensesData.password, using: req.services)
		.flatMapThrowing{ authSuccess -> Void in
			guard authSuccess else {throw "Cannot login with these credentials."}
		}
		.flatMapThrowing{ _ -> View in
			print(username)
			throw NotImplementedError()
		}
	}
	
}
