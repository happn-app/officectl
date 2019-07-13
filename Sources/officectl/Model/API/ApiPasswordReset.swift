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
	
	var userId: TaggedId
	
	var isExecuting: Bool
	var serviceResets: [ApiServicePasswordReset]
	
	init(userId uid: TaggedId, passwordResetAndServices passwordResets: [ResetPasswordActionAndService], environment: Environment) {
		userId = uid
		isExecuting = passwordResets.reduce(false, { $0 || $1.resetAction.successValue?.resetAction.isExecuting ?? false })
		serviceResets = passwordResets.map{ ApiServicePasswordReset(passwordResetAndService: $0, environment: environment) }
	}
	
}
