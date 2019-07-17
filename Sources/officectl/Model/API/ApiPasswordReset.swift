/*
 * ApiPasswordReset.swift
 * officectl
 *
 * Created by François Lamboley on 15/04/2019.
 */

import Foundation

import OfficeKit
import Service



struct ApiPasswordReset : Codable {
	
	struct ApiServicePasswordReset : Codable {
		
		var userId: String?
		
		var hasRun: Bool
		var isExecuting: Bool
		var error: ApiError?
		
		init(passwordResetAndService passwordReset: ResetPasswordActionAndService, environment: Environment) {
			userId = passwordReset.resetAction.successValue.flatMap{ passwordReset.service.string(fromUserId: $0.user.userId) }
			
			hasRun = !(passwordReset.resetAction.successValue?.resetAction.isWeak ?? false)
			isExecuting = passwordReset.resetAction.successValue?.resetAction.isExecuting ?? false
			error = (passwordReset.resetAction.failureValue ?? passwordReset.resetAction.successValue?.resetAction.result?.failureValue)
				.flatMap{ ApiError(error: $0, environment: environment) }
		}
		
	}
	
	var requestedUserId: TaggedId
	
	var isExecuting: Bool
	var serviceResets: [String: ApiServicePasswordReset]
	
	init(userId uid: TaggedId, passwordResetAndServices passwordResets: [ResetPasswordActionAndService], environment: Environment) throws {
		requestedUserId = uid
		isExecuting = passwordResets.reduce(false, { $0 || $1.resetAction.successValue?.resetAction.isExecuting ?? false })
		serviceResets = try Dictionary(
			passwordResets.map{ ($0.service.config.serviceId, ApiServicePasswordReset(passwordResetAndService: $0, environment: environment)) },
			uniquingKeysWith: { _, _ in throw InternalError(message: "Got two password resets with the same service id when initing an ApiPasswordReset") }
		)
	}
	
}
