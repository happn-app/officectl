/*
 * setup_routes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



func routes(_ routes: Routes, _ container: Container) throws {
	routes.get("api", "services", use: { req in
		try ApiResponse.data(
			req.make(OfficectlConfig.self).officeKitConfig.serviceConfigs
			.map{ kv -> ApiService in
				let (_, config) = kv
				return ApiService(providerId: config.providerId, serviceId: config.serviceId, serviceFullName: config.serviceName, isHelperService: config.isHelperService)
			}
			.sorted(by: { $0.serviceFullName.localizedCompare($1.serviceFullName) != .orderedDescending })
		)
	})
	
	routes.post("api", "auth", "login",  use: LoginController().login)
	routes.post("api", "auth", "logout", use: LogoutController().logout)
	
	let usersController = UsersController()
	routes.get("api", "users", use: usersController.getAllUsers)
	routes.get("api", "users", "me", use: usersController.getMe)
	routes.get("api", "users", AnyDSUIdPair.parameter, use: usersController.getUser)
	
	/* Intentionnally not giving access to listing of all resets: We do not keep
	 * a table of the lists of password resets, and it would not be trivial to do
	 * so we just don’t do it. */
	let passwordResetController = PasswordResetController()
	routes.get("api", "password-resets", AnyDSUIdPair.parameter, use: passwordResetController.getReset)
	routes.put("api", "password-resets", AnyDSUIdPair.parameter, use: passwordResetController.createReset)
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	routes.get("password-reset", use: webPasswordResetController.showUserSelection)
	routes.get("password-reset",  Email.parameter, use: webPasswordResetController.showResetPage)
	routes.post("password-reset", Email.parameter, use: webPasswordResetController.resetPassword)
	
	/* ******** Temporary certificate renew page ******** */
	
	let webCertificateRenewController = WebCertificateRenewController()
	routes.get("get-certificate", use: webCertificateRenewController.showLogin)
	routes.post("get-certificate", use: webCertificateRenewController.renewCertificate)
	
	/* ******** Temporary test iOS devices list ******** */
	
	let iOSTestDevicesController = IosTestDevicesController()
	routes.get("ios-test-devices", use: iOSTestDevicesController.showTestDevicesList)
}
