/*
 * ApiServicePasswordReset.swift
 * officectl
 *
 * Created by François Lamboley on 15/04/2019.
 */

import Foundation

import OfficeKit
import Service



struct ApiServicePasswordReset : Codable {
	
	var serviceId: String
	var userId: String?
	
	var hasRun: Bool
	var isExecuting: Bool
	var error: ApiError?
	
	init(passwordResetAndService passwordReset: ResetPasswordActionAndService, environment: Environment) {
		serviceId = passwordReset.service.config.serviceId
		
		userId = passwordReset.resetAction.successValue.flatMap{ passwordReset.service.string(fromUserId: $0.user.userId) }
		
		hasRun = !(passwordReset.resetAction.successValue?.resetAction.isWeak ?? false)
		isExecuting = passwordReset.resetAction.successValue?.resetAction.isExecuting ?? false
		error = (passwordReset.resetAction.failureValue ?? passwordReset.resetAction.successValue?.resetAction.result?.failureValue)
			.flatMap{ ApiError(error: $0, environment: environment) }
	}
	
}
