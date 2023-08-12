/*
 * cur-test.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/11.
 */

import Foundation

import ArgumentParser
import Email
import FormURLEncodedCoder
import JWT
import URLRequestOperation

import HappnOffice
import OfficeKit



struct CurTest : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "The current test done by the dev. Definitely do not run this if you’re not the dev.",
		shouldDisplay: false
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	@Argument
	var newUserEmail: Email
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		guard let happnService = officeKitServices.hashableUserServices(matching: "hppn").onlyElement?.value as? HappnService else {
			officectlOptions.logger.critical("happn service not found; bailing.")
			throw ExitCode(1)
		}
		
		if let user = try await happnService.existingUser(fromID: .login(newUserEmail), propertiesToFetch: nil) {
			officectlOptions.logger.debug("Deleting user", metadata: ["user_id": "\(newUserEmail)"])
			try await happnService.deleteUser(user)
			/* Probably not needed but let’s do that anyway. */
			try await Task.sleep(nanoseconds: 1_000_000_000)
		}
		
		/* Create a user. */
		let password = String.generatePassword(allowedChars: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.", length: 21)
		var user = HappnUser(login: .login(newUserEmail))
		user.firstName = "Outsourcia"
		user.lastName = "Agent"
		user.password = password
		officectlOptions.logger.debug("Creating user", metadata: ["user_id": "\(newUserEmail)"])
		let createdUser = try await happnService.createUser(user)
		print("Created user password: \(password)")
		
		let permissions = "admin_search_user,all_archive_create,all_archive_read,all_audiocall_read,all_image_create,all_image_delete,all_image_update,all_notification_read,all_order_read,all_order_update,all_recovery_token_create,all_recovery_token_read,all_report_read,all_report_update,all_user_delete,all_user_update,all_videocall_read,analytics_read,credit_update,geo_read,moderator_create,moderator_delete,moderator_read,push_campaign_create,push_campaign_read,push_campaign_update,user_ban,user_ban_bulk,user_create,user_unban"
		guard let userID = createdUser.id else {
			officectlOptions.logger.error("No user ID found in created user; not setting permission (but user is created).")
			throw ExitCode(1)
		}
		
		URLRequestOperationConfig.logger = officectlOptions.logger
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		let connector = happnService.connector
		try await connector.connect(["acl_create", "acl_update", "acl_read"])
		var request = try URLRequest(url: happnService.config.connectorSettings.baseURL.appending("api", "user-acls", userID))
		let (encoded, mimeType) = try FormURLEncodedEncoder().encodeForHTTPContent(["permissions": permissions])
		request.setValue(mimeType.rawValue, forHTTPHeaderField: "Content-Type")
		request.httpBody = encoded
		request.httpMethod = "POST"
		let operation = URLRequestDataOperation.forData(
			urlRequest: request,
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		_ = try await operation.startAndGetResult()
	}
	
}
