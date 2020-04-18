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
	
	func showUserSelection(_ req: Request) -> EventLoopFuture<View> {
		return req.view.render("NewPasswordResetPage")
	}
	
	func showResetPage(_ req: Request) throws -> EventLoopFuture<View> {
		let email = try Email.getAsParameter(named: "email", from: req)
		return try multiServicesPasswordReset(for: email, request: req)
			.flatMap{ resets in self.renderMultiServicesPasswordReset(resets, for: email, viewRenderer: req.view) }
	}
	
	func resetPassword(_ req: Request) throws -> EventLoopFuture<View> {
		let email = try Email.getAsParameter(named: "email", from: req)
		let resetPasswordData = try req.content.decode(ResetPasswordData.self)
		
		let officeKitServiceProvider = req.application.officeKitServiceProvider
		let authService = try officeKitServiceProvider.getDirectoryAuthenticatorService()
		
		let user = try authService.logicalUser(fromEmail: email, servicesProvider: officeKitServiceProvider)
		return try authService.authenticate(userId: user.userId, challenge: resetPasswordData.oldPass, using: req.services)
		.flatMapThrowing{ authSuccess -> Void in
			guard authSuccess else {throw InvalidArgumentError(message: "Cannot login with these credentials.")}
		}
		.flatMapThrowing{
			try req.application.auditLogger.log(action: "Resetting password for user email:\(email).", source: .web)
			return try self.multiServicesPasswordReset(for: email, request: req)
		}
		.flatMap{ $0 }
		.flatMapThrowing{ (multiPasswordReset: MultiServicesPasswordReset) in
			_ = try multiPasswordReset.start(newPass: resetPasswordData.newPass, weakeningMode: .always(successDelay: 180, errorDelay: 180), eventLoop: req.eventLoop)
			return self.renderMultiServicesPasswordReset(multiPasswordReset, for: email, viewRenderer: req.view)
		}
		.flatMap{ $0 }
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
	private func multiServicesPasswordReset(for email: Email, request: Request) throws -> EventLoopFuture<MultiServicesPasswordReset> {
		let sProvider = request.application.officeKitServiceProvider
		let emailService: EmailService = try sProvider.getUserDirectoryService(id: nil)
		let services = try sProvider.getAllUserDirectoryServices().filter{ $0.supportsPasswordChange }
		
		let emailUser = try emailService.logicalUser(fromUserId: email)
		return try MultiServicesPasswordReset.fetch(from: AnyDSUIdPair(service: emailService.erase(), userId: emailUser.erase().userId), in: services, using: request.services)
	}
	
	private func renderMultiServicesPasswordReset(_ multiPasswordReset: MultiServicesPasswordReset, for email: Email, viewRenderer: ViewRenderer) -> EventLoopFuture<View> {
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
		return viewRenderer.render("PasswordResetStatusPage", context)
	}
	
}
