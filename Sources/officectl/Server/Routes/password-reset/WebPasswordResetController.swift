/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 09/08/2018.
 */

import Foundation

import SemiSingleton
import Vapor

import OfficeKit



#if false
final class WebPasswordResetController {
	
	func showUserSelection(_ req: Request) throws -> Future<View> {
		return try req.view().render("NewPasswordResetPage")
	}
	
	func showResetPage(_ req: Request) throws -> Future<View> {
		let email = try req.parameters.next(Email.self)
		let officeKitConfig = try req.make(OfficeKitConfig.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let basePeopleDN = try nil2throw(officeKitConfig.ldapConfigOrThrow().peopleBaseDNPerDomain?[officeKitConfig.mainDomain(for: email.domain)], "LDAP People Base DN")
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: User(email: email, basePeopleDN: basePeopleDN, setMainIdToLDAP: true), additionalInitInfo: req) as ResetPasswordAction
		
		return try renderResetPasswordAction(resetPasswordAction, view: req.view())
	}
	
	func resetPassword(_ req: Request) throws -> Future<View> {
		let view = try req.view()
		let email = try req.parameters.next(Email.self)
		let officeKitConfig = try req.make(OfficeKitConfig.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let resetPasswordData = try req.content.syncDecode(ResetPasswordData.self)
		let basePeopleDN = try nil2throw(officeKitConfig.ldapConfigOrThrow().peopleBaseDNPerDomain?[officeKitConfig.mainDomain(for: email.domain)], "LDAP People Base DN")
		let user = User(email: email, basePeopleDN: basePeopleDN, setMainIdToLDAP: true)
		
		return try user
		.checkLDAPPassword(container: req, checkedPassword: resetPasswordData.oldPass)
		.then{ _ in
			/* The password of the user is verified. Let’s launch the reset! */
			let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: req) as ResetPasswordAction
			resetPasswordAction.start(parameters: resetPasswordData.newPass, handler: nil)
			return self.renderResetPasswordAction(resetPasswordAction, view: view)
		}
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
	private func renderResetPasswordAction(_ resetPasswordAction: ResetPasswordAction, view: ViewRenderer) -> Future<View> {
		let emailStr = resetPasswordAction.subject.email?.stringValue ?? "<unknown>"
		
		if !resetPasswordAction.isWeak {
			/* The action is either executing or finished but with a reachable
			 * result. */
			struct ResetPasswordStatusContext : Encodable {
				struct ServicePasswordResetStatus : Encodable {
					var isExecuting: Bool
					var errorStr: String?
				}
				var userEmail: String
				var isExecuting: Bool
				var isSuccessful: Bool
				var ldapResetStatus: ServicePasswordResetStatus
				var googleResetStatus: ServicePasswordResetStatus
				var openDirectoryResetStatus: ServicePasswordResetStatus
			}
			
			let isOpenDirectoryBeingReset: Bool
			#if canImport(DirectoryService) && canImport(OpenDirectory)
			isOpenDirectoryBeingReset = resetPasswordAction.resetOpenDirectoryPasswordAction.isExecuting
			#else
			isOpenDirectoryBeingReset = false
			#endif
			let context = ResetPasswordStatusContext(
				userEmail: emailStr,
				isExecuting: resetPasswordAction.isExecuting,
				isSuccessful: resetPasswordAction.result?.isSuccessful ?? false,
				ldapResetStatus: ResetPasswordStatusContext.ServicePasswordResetStatus(
					isExecuting: resetPasswordAction.ldapResetResult == nil || resetPasswordAction.resetLDAPPasswordAction.isExecuting,
					errorStr: resetPasswordAction.ldapResetResult?.failureValue?.legibleLocalizedDescription
				),
				googleResetStatus: ResetPasswordStatusContext.ServicePasswordResetStatus(
					isExecuting: resetPasswordAction.googleResetResult == nil || resetPasswordAction.resetGooglePasswordAction.isExecuting,
					errorStr: resetPasswordAction.googleResetResult?.failureValue?.legibleLocalizedDescription
				),
				openDirectoryResetStatus: ResetPasswordStatusContext.ServicePasswordResetStatus(
					isExecuting: resetPasswordAction.openDirectoryResetResult == nil || isOpenDirectoryBeingReset,
					errorStr: resetPasswordAction.openDirectoryResetResult?.failureValue?.legibleLocalizedDescription
				)
			)
			return view.render("PasswordResetStatusPage", context)
			
		} else {
			return view.render("NewPasswordResetPage", ["user_email": emailStr])
			
		}
	}
	
}
#endif
