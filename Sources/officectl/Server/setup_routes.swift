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
	router.get("api", "services", use: { _ in
		ApiResponse.data([
			ApiService(serviceId: "ldap",   serviceFullName: "LDAP", serviceDescription: "An LDAP server (tested with OpenLDAP)"),
			ApiService(serviceId: "ggl",    serviceFullName: "Google Apps", serviceDescription: "Google Apps Service"),
			ApiService(serviceId: "github", serviceFullName: "GitHub", serviceDescription: "GitHub (non-enterprise)"),
			ApiService(serviceId: "email",  serviceFullName: "Simple Email", serviceDescription: "To identify users via their email"),
		])
	})
	
	router.post("api", "auth", "login",  use: LoginController().login)
	router.post("api", "auth", "logout", use: LogoutController().logout)
	
	let usersController = UsersController()
	router.get("api", "users", use: usersController.getUsers)
	router.get("api", "users", UserId.parameter, use: usersController.getUser)
	router.get("api", "search-users", use: usersController.searchUsers)
	
	let passwordResetController = PasswordResetController()
	router.get("api", "password-resets", use: passwordResetController.getResets)
	router.get("api", "password-resets", UserId.parameter, use: passwordResetController.getReset)
	router.put("api", "password-resets", UserId.parameter, use: passwordResetController.createReset)
	router.delete("api", "password-resets", UserId.parameter, use: passwordResetController.deleteReset)
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	router.get("password-reset", use: webPasswordResetController.showUserSelection)
	router.get("password-reset",  Email.parameter, use: webPasswordResetController.showResetPage)
	router.post("password-reset", Email.parameter, use: webPasswordResetController.resetPassword)
	
	/* ******** Temporary certificate renew page ******** */
	
	let webCertificateRenewController = WebCertificateRenewController()
	router.get("certificate-renew", use: webCertificateRenewController.showLogin)
	router.post("certificate-renew", use: webCertificateRenewController.renewCertificate)
}
