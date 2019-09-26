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
		return try multiServicesPasswordReset(for: email, container: req)
		.flatMap{ resets in try self.renderMultiServicesPasswordReset(resets, for: email, view: req.view()) }
	}
	
	func resetPassword(_ req: Request) throws -> Future<View> {
		let view = try req.view()
		let email = try req.parameters.next(Email.self)
		let resetPasswordData = try req.content.syncDecode(ResetPasswordData.self)
		
		let officeKitServiceProvider = try req.make(OfficeKitServiceProvider.self)
		let authService = try officeKitServiceProvider.getDirectoryAuthenticatorService()
		
		let user = try authService.logicalUser(fromEmail: email, servicesProvider: officeKitServiceProvider)
		return try authService.authenticate(userId: user.userId, challenge: resetPasswordData.oldPass, on: req)
		.map{ authSuccess -> Void in
			guard authSuccess else {throw BasicValidationError("Cannot login with these credentials.")}
		}
		.flatMap{
			try req.make(AuditLogger.self).log(action: "Resetting password for user email:\(email).", source: .web)
			return try self.multiServicesPasswordReset(for: email, container: req)
		}
		.flatMap{ (multiPasswordReset: MultiServicesPasswordReset) in
			_ = try multiPasswordReset.start(newPass: resetPasswordData.newPass, weakeningMode: .always(successDelay: 180, errorDelay: 180), eventLoop: req.eventLoop)
			return self.renderMultiServicesPasswordReset(multiPasswordReset, for: email, view: view)
		}
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
	private func multiServicesPasswordReset(for email: Email, container: Container) throws -> EventLoopFuture<MultiServicesPasswordReset> {
		let sProvider = try container.make(OfficeKitServiceProvider.self)
		let emailService: EmailService = try sProvider.getUserDirectoryService(id: nil)
		let services = try sProvider.getAllUserDirectoryServices().filter{ $0.supportsPasswordChange }
		
		let emailUser = try emailService.logicalUser(fromUserId: email)
		return try MultiServicesPasswordReset.fetch(from: AnyDSUIdPair(service: emailService.erased(), user: emailUser.erased().userId), in: services, on: container)
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
			servicesResetStatus: multiPasswordReset.errorsAndItemsByService.sorted(by: { $0.key.config.serviceName.localizedCompare($1.key.config.serviceName) != .orderedDescending }).map{
				ResetPasswordStatusContext.ServicePasswordResetStatus(
					serviceName: $0.key.config.serviceName,
					isExecuting: $0.value.successValue??.passwordReset.isExecuting ?? false,
					hasRun: !($0.value.successValue.flatMap{ $0?.passwordReset.isWeak ?? true } ?? false),// !($0.value.successValue??.passwordReset.isWeak ?? false),
					errorStr: ($0.value.failureValue ?? $0.value.successValue??.passwordReset.result?.failureValue)?.legibleLocalizedDescription
				)
			}
		)
		return view.render("PasswordResetStatusPage", context)
	}
	
}
