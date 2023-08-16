/*
 * cur-test.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/11.
 */

import Foundation

import ArgumentParser
import CollectionConcurrencyKit
import Email
import FormURLEncodedCoder
import JWT
import UnwrapOrThrow
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
	var emails: String
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		guard let happnService = officeKitServices.hashableUserServices(matching: "hppn").onlyElement?.value as? HappnService else {
			officectlOptions.logger.critical("happn service not found; bailing.")
			throw ExitCode(1)
		}
		
		URLRequestOperationConfig.logger = officectlOptions.logger
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		
		let userIDs = try await emails.split(separator: ",").compactMap{ Email(rawValue: String($0)) }
			.concurrentCompactMap{ email in
				try await happnService.existingUser(fromID: .login(email), propertiesToFetch: nil)?.id
			}
		print("Got user IDs: \(userIDs)")
		
		let connector = happnService.connector
		try await connector.connect(["acl_create", "acl_update", "acl_read"])
		
		let expectedPermissions = "admin_search_user,all_archive_create,all_archive_read,all_audiocall_read,all_image_create,all_image_delete,all_image_update,all_notification_read,all_order_read,all_order_update,all_payment_read,all_payment_write,all_recovery_token_create,all_recovery_token_read,all_report_read,all_report_update,all_user_delete,all_user_update,all_videocall_read,analytics_read,credit_update,geo_read,moderator_create,moderator_delete,moderator_read,push_campaign_create,push_campaign_read,push_campaign_update,user_ban,user_ban_bulk,user_create,user_unban"
//		let permissions = await userIDs.concurrentMap{ userID -> Result<[String], Error> in
//			return await Result{
//				let operation = try URLRequestDataOperation<HappnApiResult<HappnUserACL>>.forAPIRequest(
//					url: happnService.config.connectorSettings.baseURL.appending("api", "user-acls", userID),
//					requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
//				)
//				return try await (operation.startAndGetResult().result.data ?! DummyError())
//					.acl.map(\.id)
//			}
//		}
//		permissions.forEach{
//			print($0.success?.sorted().joined(separator: ",") ?? "\($0.failure!)")
//		}
		
		/* Set ACLs of user. */
		_ = try await userIDs.concurrentMap{ userID in
			let operation = try URLRequestDataOperation<HappnApiResult<[HappnACL]>>.forAPIRequest(
				url: happnService.config.connectorSettings.baseURL.appending("api", "user-acls", userID),
				httpBody: ["permissions": expectedPermissions],
				bodyEncoder: FormURLEncodedEncoder(),
				requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
			)
			_ = try await operation.startAndGetResult()
		}
	}
	
}


private struct DummyError : Error {}

/* This is actually a normal User entity, but HappnOffice does not have the acl key in the user model, so we create a lightweight model that suits our needs.
 * Of course, if this were a standard user model, the acl property would be optional. */
private struct HappnUserACL : Sendable, Decodable {
	
	var id: String
	var acl: [HappnACL]
	
}

private struct HappnACL : Sendable, Decodable {
	
	/* All of these keys are equal AFAICT.
	 * Maybe they _could_ be different, but they are currently not. */
	var id: String
	var name: String
	var permissionKey: String
	var descr: String?
	
}

/* Copy-pasted from HappnOffice. */
private struct HappnApiResult<DataType : Sendable & Decodable> : Sendable, Decodable {
	
	var success: Bool
	var data: DataType?
	
	var status: Int
	var error: String?
	var errorCode: Int
	
	internal enum CodingKeys : String, CodingKey {
		
		case success, data
		case status, error, errorCode = "error_code"
		
	}
	
}
