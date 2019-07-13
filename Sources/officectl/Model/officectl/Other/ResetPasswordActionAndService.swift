/*
 * ResetPasswordActionAndService.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation

import OfficeKit
import Service



struct ResetPasswordActionAndService {
	
	var service: AnyDirectoryService
	var resetAction: Result<(user: AnyDirectoryUser, resetAction: ResetPasswordAction), Error>
	
	init(destinationService s: AnyDirectoryService, sourceUser: AnyDirectoryUser, sourceService: AnyDirectoryService, container: Container) {
		service = s
		resetAction = Result{
			let user = try s.logicalUser(fromUser: sourceUser, in: sourceService, hints: [:])
			return try (user, s.changePasswordAction(for: user, on: container))
		}
	}
	
	init(destinationService s: AnyDirectoryService, email: Email, container: Container) {
		service = s
		resetAction = Result{
			let user = try s.logicalUser(fromEmail: email, hints: [:])
			return try (user, s.changePasswordAction(for: user, on: container))
		}
	}
	
}
