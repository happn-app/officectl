/*
 * ApiPasswordReset+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/30.
 */

import Foundation

import Vapor

import OfficeKit
import OfficeModel



extension ApiPasswordReset {
	
	init(requestedUserId uid: TaggedId, multiPasswordResets: MultiServicesPasswordReset, environment: Environment) {
		self.init(
			requestedUserId: uid,
			fetchErrorsByServiceId: multiPasswordResets.errorsByServiceId.mapValues{ ApiError(error: $0, environment: environment) },
			isExecuting: multiPasswordResets.isExecuting,
			serviceResets: multiPasswordResets.itemsByServiceId.mapValues{ resetPair in
				resetPair.flatMap{ ApiServicePasswordReset(passwordResetPair: $0, environment: environment) }
			}
		)
	}
	
}
