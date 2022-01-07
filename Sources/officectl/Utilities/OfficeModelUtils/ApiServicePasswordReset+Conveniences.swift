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
		let status: Status
		if passwordResetPair.passwordReset.isWeak {
			/* We are guaranteed by Action’s doc that here the reset is not executing. */
			status = .idle
		} else {
			if passwordResetPair.passwordReset.isExecuting {
				status = .running
			} else {
				status = .ranRecently(error: passwordResetPair.passwordReset.result?.failureValue.flatMap{ ApiError(error: $0, environment: environment) })
			}
		}
		self.init(
			serviceID: passwordResetPair.dsuPair.serviceID,
			userID: passwordResetPair.dsuPair.taggedID.id,
			status: status
		)
	}
	
}
