/*
 * ApiServicePasswordReset.swift
 * officectl
 *
 * Created by François Lamboley on 15/04/2019.
 */

import Foundation

import OfficeKit



struct ApiServicePasswordReset : Codable {
	
	var serviceId: String
	
	var userId: UserId
	var serviceUserId: String?
	
	var isExecuting: Bool
	var error: ApiError?
	
	init(ldapPasswordReset: ResetLDAPPasswordAction) {
		serviceId = "LDAP"
		userId = ldapPasswordReset.subject.id
		serviceUserId = ldapPasswordReset.subject.distinguishedName?.stringValue
		
		isExecuting = ldapPasswordReset.isExecuting
		error = ldapPasswordReset.result?.failureValue.flatMap{ ApiError(error: $0, environment: ldapPasswordReset.container.environment) }
	}
	
	init(googlePasswordReset: ResetGooglePasswordAction) {
		serviceId = "Google"
		userId = googlePasswordReset.subject.id
		serviceUserId = googlePasswordReset.googleUserId
		
		isExecuting = googlePasswordReset.isExecuting
		error = googlePasswordReset.result?.failureValue.flatMap{ ApiError(error: $0, environment: googlePasswordReset.container.environment) }
	}
	
}
