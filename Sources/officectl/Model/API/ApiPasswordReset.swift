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
		
		init(passwordResetPair: AnyDSPasswordResetPair, environment: Environment) {
			userId = passwordResetPair.dsuPair.taggedId.id
			
			hasRun = !passwordResetPair.passwordReset.isWeak
			isExecuting = passwordResetPair.passwordReset.isExecuting
			error = passwordResetPair.passwordReset.result?.failureValue.flatMap{ ApiError(error: $0, environment: environment) }
		}
		
	}
	
	var requestedUserId: TaggedId
	var fetchErrorsByServiceId: [String: ApiError]
	
	var isExecuting: Bool
	var serviceResets: [String: ApiServicePasswordReset?]
	
	init(requestedUserId uid: TaggedId, multiPasswordResets: MultiServicesPasswordReset, environment: Environment) {
		requestedUserId = uid
		fetchErrorsByServiceId = multiPasswordResets.errorsByServiceId.mapValues{ ApiError(error: $0, environment: environment) }
		
		isExecuting = multiPasswordResets.isExecuting
		serviceResets = multiPasswordResets.itemsByServiceId.mapValues{ resetPair in
			resetPair.flatMap{ ApiServicePasswordReset(passwordResetPair: $0, environment: environment) }
		}
	}
	
}
