/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 2018/08/09.
 */

import Foundation

import Email
import LegibleError
import SemiSingleton
import Vapor

import OfficeKit



final class WebPasswordResetController {
	
	func showHome(_ req: Request) async throws -> View {
		struct PasswordResetContext : Encodable {
			var isAdmin: Bool
			var userEmail: String
		}
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let email = try loggedInUser.user.hop(to: emailService).user.userID
		return try await req.view.render("PasswordResetHome", PasswordResetContext(isAdmin: loggedInUser.isAdmin, userEmail: email.rawValue))
	}
	
	func showResetPage(_ req: Request) async throws -> View {
		let email = try Email.getAsParameter(named: "email", from: req)
		
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		guard try loggedInUser.isAdmin || loggedInUser.representsSameUserAs(dsuIDPair: AnyDSUIDPair(service: emailService.erase(), userID: email.erase()), request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only see their own password reset status.")
		}
		
		return try await renderMultiServicesPasswordReset(
			multiServicesPasswordReset(for: email, request: req),
			for: email,
			viewRenderer: req.view
		)
	}
	
	func resetPassword(_ req: Request) async throws -> View {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		let email = try Email.getAsParameter(named: "email", from: req)
		let resetPasswordData = try req.content.decode(ResetPasswordData.self)
		
		let officeKitServiceProvider = req.application.officeKitServiceProvider
		let emailService: EmailService = try officeKitServiceProvider.getService(id: nil)
		
		guard try loggedInUser.isAdmin || loggedInUser.representsSameUserAs(dsuIDPair: AnyDSUIDPair(service: emailService.erase(), userID: email.erase()), request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only reset their own password.")
		}
		
		if let oldPass = resetPasswordData.oldPass {
			let authService = try officeKitServiceProvider.getDirectoryAuthenticatorService()
			let authServiceUser = try authService.logicalUser(fromEmail: email, servicesProvider: officeKitServiceProvider)
			guard try await authService.authenticate(userID: authServiceUser.userID, challenge: oldPass, using: req.services) else {
				throw Abort(.forbidden, reason: "Invalid old password.")
			}
		} else {
			/* Only admins are allowed to change the pass of someone without specifying the old password. */
			guard loggedInUser.isAdmin else {throw Abort(.forbidden, reason: "Old password is required for non-admin users")}
		}
		
		try req.application.auditLogger.log(action: "Resetting password for user email: \(email).", source: .web)
		
		let multiPasswordReset = try await multiServicesPasswordReset(for: email, request: req)
		Task.detached{ try await multiPasswordReset.start(newPass: resetPasswordData.newPass, weakeningMode: .always(successDelay: 180, errorDelay: 180)) }
		return try await renderMultiServicesPasswordReset(multiPasswordReset, for: email, viewRenderer: req.view)
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String?
		var newPass: String
		
	}
	
	private func multiServicesPasswordReset(for email: Email, request: Request) async throws -> MultiServicesPasswordReset {
		let sProvider = request.application.officeKitServiceProvider
		let emailService: EmailService = try sProvider.getUserDirectoryService(id: nil)
		let services = try sProvider.getAllUserDirectoryServices().filter{ $0.supportsPasswordChange }
		
		let emailUser = try emailService.logicalUser(fromUserID: email)
		return try await MultiServicesPasswordReset.fetch(from: AnyDSUIDPair(service: emailService.erase(), userID: emailUser.erase().userID), in: services, using: request.services)
	}
	
	private func renderMultiServicesPasswordReset(_ multiPasswordReset: MultiServicesPasswordReset, for email: Email, viewRenderer: ViewRenderer) async throws -> View {
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
			userEmail: email.rawValue,
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
		return try await viewRenderer.render("PasswordResetStatus", context)
	}
	
}
