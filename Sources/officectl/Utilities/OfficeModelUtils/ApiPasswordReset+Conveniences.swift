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
			isExecuting: multiPasswordResets.isExecuting,
			serviceResets: multiPasswordResets.errorsAndItemsByServiceID.compactMapValues{ resetPairResult in
				switch resetPairResult {
					case .success(let resetPair): return resetPair.flatMap{ .success(ApiServicePasswordReset(passwordResetPair: $0, environment: environment)) }
					case .failure(let error):     return .failure(ApiError(error: error, environment: environment))
				}
				
			}
		)
	}
	
}
