/*
 * setup_routes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



func setup_routes(_ router: Router) throws {
	router.get("api", "services", use: { req in
		try ApiResponse.data(
			req.make(OfficectlConfig.self).officeKitConfig.serviceConfigs
			.map{ kv -> ApiService in
				let (_, config) = kv
				return ApiService(providerId: config.providerId, serviceId: config.serviceId, serviceFullName: config.serviceName, isHelperService: config.isHelperService)
			}
			.sorted(by: { $0.serviceFullName.localizedCompare($1.serviceFullName) != .orderedDescending })
		)
	})
	
	router.post("api", "auth", "login",  use: LoginController().login)
	router.post("api", "auth", "logout", use: LogoutController().logout)
	
	let usersController = UsersController()
	router.get("api", "users", use: usersController.getAllUsers)
	router.get("api", "users", "me", use: usersController.getMe)
	router.get("api", "users", AnyDSUIdPair.parameter, use: usersController.getUser)
	
	/* Intentionnally not giving access to listing of all resets: We do not keep
	 * a table of the lists of password resets, and it would not be trivial to do
	 * so we just don’t do it. */
	let passwordResetController = PasswordResetController()
	router.get("api", "password-resets", AnyDSUIdPair.parameter, use: passwordResetController.getReset)
	router.put("api", "password-resets", AnyDSUIdPair.parameter, use: passwordResetController.createReset)
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	router.get("password-reset", use: webPasswordResetController.showUserSelection)
	router.get("password-reset",  Email.parameter, use: webPasswordResetController.showResetPage)
	router.post("password-reset", Email.parameter, use: webPasswordResetController.resetPassword)
	
	/* ******** Temporary certificate renew page ******** */
	
	let webCertificateRenewController = WebCertificateRenewController()
	router.get("get-certificate", use: webCertificateRenewController.showLogin)
	router.post("get-certificate", use: webCertificateRenewController.renewCertificate)
	
	/* ******** Temporary test iOS devices list ******** */
	
	let iOSTestDevicesController = IosTestDevicesController()
	router.get("ios-test-devices", use: iOSTestDevicesController.showTestDevicesList)
}
