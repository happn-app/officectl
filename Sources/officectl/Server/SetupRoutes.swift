/*
 * SetupRoutes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



func setup_routes(_ app: Application) throws {
	app.get("api", "services", use: { req in
		ApiResponse.data(
			req.make(OfficectlConfig.self).officeKitConfig.serviceConfigs
			.map{ kv -> ApiService in
				let (_, config) = kv
				return ApiService(providerId: config.providerId, serviceId: config.serviceId, serviceFullName: config.serviceName, isHelperService: config.isHelperService)
			}
			.sorted(by: { $0.serviceFullName.localizedCompare($1.serviceFullName) != .orderedDescending })
		)
	})
	
	app.post("api", "auth", "login",  use: LoginController().login)
	app.post("api", "auth", "logout", use: LogoutController().logout)
	
	let usersController = UsersController()
	app.get("api", "users", use: usersController.getAllUsers)
	app.get("api", "users", "me", use: usersController.getMe)
	app.get("api", "users", ":dsuid-pair", use: usersController.getUser)
	
	/* Intentionnally not giving access to listing of all resets: We do not keep
	 * a table of the lists of password resets, and it would not be trivial to do
	 * so we just don’t do it. */
	let passwordResetController = PasswordResetController()
	app.get("api", "password-resets", ":dsuid-pair", use: passwordResetController.getReset)
	app.put("api", "password-resets", ":dsuid-pair", use: passwordResetController.createReset)
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	app.get("password-reset", use: webPasswordResetController.showUserSelection)
	app.get("password-reset",  ":email", use: webPasswordResetController.showResetPage)
	app.post("password-reset", ":email", use: webPasswordResetController.resetPassword)
	
	/* ******** Temporary certificate renew page ******** */
	
	let webCertificateRenewController = WebCertificateRenewController()
	app.get("get-certificate", use: webCertificateRenewController.showLogin)
	app.post("get-certificate", use: webCertificateRenewController.renewCertificate)
	
	/* ******** Temporary test iOS devices list ******** */
	
	let iOSTestDevicesController = IosTestDevicesController()
	app.get("ios-test-devices", use: iOSTestDevicesController.showTestDevicesList)
}
