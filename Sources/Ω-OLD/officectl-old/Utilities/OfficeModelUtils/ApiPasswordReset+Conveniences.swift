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
			results: multiPasswordResets.errorsAndItemsByServiceID.mapValues{ ApiResult(result: $0.map{ $0.flatMap{ ApiDirectoryPasswordReset(passwordResetPair: $0, environment: environment) } }, environment: environment) },
			mergedResults: ApiMergedPasswordReset(isExecuting: multiPasswordResets.isExecuting)
		)
	}
	
}
