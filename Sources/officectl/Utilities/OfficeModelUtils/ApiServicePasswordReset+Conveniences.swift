/*
 * ApiServicePasswordReset+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/30.
 */

import Foundation

import Vapor

import OfficeKit
import OfficeModel



extension ApiServicePasswordReset {
	
	init(passwordResetPair: AnyDSPasswordResetPair, environment: Environment) {
		self.init(
			userId: passwordResetPair.dsuPair.taggedId.id,
			hasRun: !passwordResetPair.passwordReset.isWeak,
			isExecuting: passwordResetPair.passwordReset.isExecuting,
			error: passwordResetPair.passwordReset.result?.failureValue.flatMap{ ApiError(error: $0, environment: environment) }
		)
	}
	
}
