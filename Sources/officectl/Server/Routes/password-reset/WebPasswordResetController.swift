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



final class WebPasswordResetController {
	
	func showUserSelection(_ req: Request) throws -> Future<View> {
		return try req.view().render("NewPasswordResetPage")
	}
	
	func showResetPage(_ req: Request) throws -> Future<View> {
		let email = try req.parameters.next(Email.self)
		let actions = try multiServicesPasswordReset(for: email, container: req)
		return try renderMultiServicesPasswordReset(actions, for: email, view: req.view())
	}
	
	func resetPassword(_ req: Request) throws -> Future<View> {
		let view = try req.view()
		let email = try req.parameters.next(Email.self)
		let resetPasswordData = try req.content.syncDecode(ResetPasswordData.self)
		
		let officeKitServiceProvider = try req.make(OfficeKitServiceProvider.self)
		let authService = try officeKitServiceProvider.getDirectoryAuthenticatorService()
		
		let genericUser = DirectoryUserWrapper(email: email)
		let user = try authService.logicalUser(fromWrappedUser: genericUser)
		return try authService.authenticate(userId: user.userId, challenge: resetPasswordData.oldPass, on: req)
		.map{ authSuccess -> Void in
			guard authSuccess else {throw BasicValidationError("Cannot login with these credentials.")}
		}
		.flatMap{
			try req.make(AuditLogger.self).log(action: "Resetting password for user email:\(email).", source: .web)
			
			let multiPasswordReset = try self.multiServicesPasswordReset(for: email, container: req)
			_ = try multiPasswordReset.start(newPass: resetPasswordData.newPass, weakeningMode: .always(successDelay: 180, errorDelay: 180), eventLoop: req.eventLoop)
			return self.renderMultiServicesPasswordReset(multiPasswordReset, for: email, view: view)
		}
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
	private func multiServicesPasswordReset(for email: Email, container: Container) throws -> MultiServicesPasswordReset {
		#warning("TODO")
		throw NotImplementedError()
//		let officeKitServiceProvider = try container.make(OfficeKitServiceProvider.self)
//		return try officeKitServiceProvider
//			.getAllServices()
//			.sorted{ $0.config.serviceName < $1.config.serviceName }
//			.filter{ $0.supportsPasswordChange }
//			.map{ ResetPasswordActionAndService(destinationService: $0, email: email, container: container) }
	}
	
	private func renderMultiServicesPasswordReset(_ multiPasswordReset: MultiServicesPasswordReset, for email: Email, view: ViewRenderer) -> Future<View> {
		struct ResetPasswordStatusContext : Encodable {
			struct ServicePasswordResetStatus : Encodable {
				var serviceName: String
				var isExecuting: Bool
				var hasRun: Bool
				var errorStr: String?
			}
			
			var userEmail: String
			var isExecuting: Bool
			
			var servicesResetStatus: [ServicePasswordResetStatus]
		}
		
		let context = ResetPasswordStatusContext(
			userEmail: email.stringValue,
			isExecuting: multiPasswordReset.isExecuting,
			servicesResetStatus: multiPasswordReset.errorsAndItemsByService.map{
				ResetPasswordStatusContext.ServicePasswordResetStatus(
					serviceName: $0.key.config.serviceName,
					isExecuting: $0.value.successValue??.passwordReset.isExecuting ?? false,
					hasRun: !($0.value.successValue??.passwordReset.isWeak ?? false),
					errorStr: ($0.value.failureValue ?? $0.value.successValue??.passwordReset.result?.failureValue)?.legibleLocalizedDescription
				)
			}
		)
		return view.render("PasswordResetStatusPage", context)
	}
	
}
