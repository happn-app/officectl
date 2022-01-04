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
	
	init(requestedUserID uid: TaggedID, multiPasswordResets: MultiServicesPasswordReset, environment: Environment) {
		self.init(
			requestedUserID: uid,
			fetchErrorsByServiceID: multiPasswordResets.errorsByServiceID.mapValues{ ApiError(error: $0, environment: environment) },
			isExecuting: multiPasswordResets.isExecuting,
			serviceResets: multiPasswordResets.itemsByServiceID.mapValues{ resetPair in
				resetPair.flatMap{ ApiServicePasswordReset(passwordResetPair: $0, environment: environment) }
			}
		)
	}
	
}
