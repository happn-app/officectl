/*
 * experimental--console-perm.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/17.
 */

import Foundation

import ArgumentParser
import Email
import FormURLEncodedCoder
import UnwrapOrThrow
import URLRequestOperation

import HappnOffice
import OfficeKit



struct Experimental_ConsolePerm : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "console-perm",
		abstract: "Set the console permissions for a given user in the happn console."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	@Argument
	var group: String
	
	@Argument
	var emails: [Email]
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		guard let happnService = officeKitServices.hashableUserServices(matching: "hppn").onlyElement?.value as? HappnService else {
			officectlOptions.logger.critical("happn service not found; bailing.")
			throw ExitCode(1)
		}
		
		let requestedPermissions: String
		switch group {
			case "acquisition": requestedPermissions = "admin_search_user,all_device_read,all_order_read,analytics_read,geo_read,geo_write,countries_read"
			case "content":     requestedPermissions = ""
			case "data":        requestedPermissions = "admin_search_user,all_shop_read,countries_create,countries_delete,countries_read,countries_update,geo_read,geo_write,pack_create,pack_delete,pack_update,shop_write,segment_read"
			case "back-end":    requestedPermissions = "achievement_type_create,achievement_type_delete,achievement_type_update,admin_search_user,all_accepted_create,all_accepted_delete,all_accepted_read,all_achievement_create,all_achievement_delete,all_achievement_read,all_achievement_update,all_availability_create,all_availability_delete,all_availability_read,all_availability_update,all_blocked_create,all_blocked_delete,all_blocked_read,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_device_create,all_device_delete,all_device_read,all_device_update,all_image_create,all_image_delete,all_image_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_notification_create,all_notification_delete,all_notification_read,all_notification_update,all_order_create,all_order_delete,all_order_read,all_order_update,all_position_read,all_position_update,all_rejected_create,all_rejected_delete,all_rejected_read,all_report_create,all_report_delete,all_report_read,all_report_update,all_shop_read,all_social_create,all_social_delete,all_social_read,all_social_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_segment_read,all_user_update,analytics_read,application_setting_create,application_setting_delete,application_setting_read,application_setting_update,applications_create,applications_delete,applications_read,applications_update,countries_create,countries_delete,countries_read,countries_update,coupon_create,coupon_delete,coupon_read,coupon_update,credit_create,credit_delete,credit_read,credit_update,geo_read,geo_write,language_create,language_delete,language_update,locale_create,locale_delete,locale_update,moderator_create,moderator_delete,moderator_read,moderator_update,notification_type_create,notification_type_delete,notification_type_update,pack_create,pack_delete,pack_update,permission_read,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,report_type_create,report_type_delete,report_type_update,reported_conversation_read,segment_create,segment_delete,segment_read,segment_update,shop_write,subscription_type_create,subscription_type_delete,subscription_type_update,translation_create,translation_delete,translation_read,translation_update,user_ban,user_ban_bulk,user_create,user_mode_create,user_mode_delete,user_mode_update,user_unban"
			case "mobile":      requestedPermissions = "achievement_type_create,achievement_type_delete,achievement_type_update,admin_search_user,all_accepted_create,all_accepted_delete,all_accepted_read,all_achievement_create,all_achievement_delete,all_achievement_read,all_achievement_update,all_availability_create,all_availability_delete,all_availability_read,all_availability_update,all_blocked_create,all_blocked_delete,all_blocked_read,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_device_create,all_device_delete,all_device_read,all_device_update,all_image_create,all_image_delete,all_image_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_notification_create,all_notification_delete,all_notification_read,all_notification_update,all_order_create,all_order_delete,all_order_read,all_order_update,all_position_read,all_position_update,all_rejected_create,all_rejected_delete,all_rejected_read,all_report_create,all_report_delete,all_report_read,all_report_update,all_social_create,all_social_delete,all_social_read,all_social_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_update,analytics_read,application_setting_create,application_setting_delete,application_setting_read,application_setting_update,applications_create,applications_delete,applications_read,applications_update,countries_create,countries_delete,countries_read,countries_update,coupon_create,coupon_delete,coupon_read,coupon_update,credit_create,credit_delete,credit_read,credit_update,geo_read,geo_write,language_create,language_delete,language_update,locale_create,locale_delete,locale_update,moderator_create,moderator_delete,moderator_read,moderator_update,notification_type_create,notification_type_delete,notification_type_update,pack_create,pack_delete,pack_update,permission_read,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,report_type_create,report_type_delete,report_type_update,reported_conversation_read,subscription_type_create,subscription_type_delete,subscription_type_update,translation_create,translation_delete,translation_read,translation_update,user_ban,user_create,user_mode_create,user_mode_delete,user_mode_update,user_unban"
			case "crm":         requestedPermissions = "admin_search_user,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_order_read,all_user_update,analytics_read,countries_read,coupon_read,geo_read,moderator_create,moderator_delete,moderator_read,moderator_update,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,reported_conversation_read"
			case "ads":         requestedPermissions = "admin_search_user,all_device_read,all_order_read,analytics_read,geo_read,geo_write,countries_read"
			case "rh":          requestedPermissions = ""
			case "finance":     requestedPermissions = ""
			case "ops":         requestedPermissions = "achievement_type_create,achievement_type_delete,achievement_type_update,acl_create,acl_delete,acl_read,acl_update,admin_create,admin_delete,admin_read,admin_search_user,all_accepted_create,all_accepted_delete,all_accepted_read,all_achievement_create,all_achievement_delete,all_achievement_read,all_achievement_update,all_archive_create,all_archive_read,all_availability_create,all_availability_delete,all_availability_read,all_availability_update,all_blocked_create,all_blocked_delete,all_blocked_read,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_device_create,all_device_delete,all_device_read,all_device_update,all_image_create,all_image_delete,all_image_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_notification_create,all_notification_delete,all_notification_read,all_notification_update,all_order_create,all_order_delete,all_order_read,all_order_update,all_position_read,all_position_update,all_rejected_create,all_rejected_delete,all_rejected_read,all_report_create,all_report_delete,all_report_read,all_report_update,all_shop_read,all_social_create,all_social_delete,all_social_read,all_social_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_segment_read,all_user_update,analytics_read,application_setting_create,application_setting_delete,application_setting_read,application_setting_update,applications_create,applications_delete,applications_read,applications_update,countries_create,countries_delete,countries_read,countries_update,coupon_create,coupon_delete,coupon_read,coupon_update,credit_create,credit_delete,credit_read,credit_update,geo_read,geo_write,language_create,language_delete,language_update,locale_create,locale_delete,locale_update,moderator_create,moderator_delete,moderator_read,moderator_update,notification_type_create,notification_type_delete,notification_type_update,pack_create,pack_delete,pack_update,permission_read,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,report_type_create,report_type_delete,report_type_update,reported_conversation_read,segment_create,segment_delete,segment_read,segment_update,shop_write,subscription_type_create,subscription_type_delete,subscription_type_update,translation_create,translation_delete,translation_read,translation_update,user_ban,user_ban_bulk,user_create,user_mode_create,user_mode_delete,user_mode_update,user_unban"
			case "support":     requestedPermissions = "admin_search_user,all_archive_create,all_archive_read,all_image_create,all_image_delete,all_image_update,all_notification_read,all_order_read,all_order_update,all_recovery_token_create,all_recovery_token_read,all_report_read,all_report_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_update,all_videocall_read,analytics_read,credit_update,geo_read,moderator_create,moderator_delete,moderator_read,push_campaign_create,push_campaign_read,push_campaign_update,user_ban,user_ban_bulk,user_create,user_unban"
			case "ext-support": requestedPermissions = "admin_search_user,all_archive_create,all_archive_read,all_audiocall_read,all_image_create,all_image_delete,all_image_update,all_notification_read,all_order_read,all_order_update,all_recovery_token_create,all_recovery_token_read,all_report_read,all_report_update,all_user_delete,all_user_update,all_videocall_read,analytics_read,credit_update,geo_read,moderator_create,moderator_delete,moderator_read,push_campaign_create,push_campaign_read,push_campaign_update,user_ban,user_ban_bulk,user_create,user_unban"
			default:
				officectlOptions.logger.error("Unknown group \(group); bailing.")
				throw ExitCode(1)
		}
		
		let users = try await emails
			.concurrentCompactMap{ email in
				let user = try await happnService.existingUser(fromID: .login(email), propertiesToFetch: nil)
				if user == nil {
					officectlOptions.logger.warning("Could not find happn user for given email.", metadata: [LMK.email: "\(email)"])
				}
				return user
			}
			.filter{ $0.id != nil }
		
		if !officectlOptions.yes {
			/* Let’s confirm everything is ok before doing the change. */
			var stderrStream = StderrStream()
			print("Will try and update the permissions on these users:", to: &stderrStream)
			for user in users {
				print("   - \(happnService.shortDescription(fromUser: user))", to: &stderrStream)
			}
			print("Will set permissions to: “\(requestedPermissions)”.", to: &stderrStream)
			print("", to: &stderrStream)
			guard try UserConfirmation.confirmYesOrNo(inputFileHandle: .standardInput, outputStream: &stderrStream) else {
				throw ExitCode(1)
			}
		} else {
			officectlOptions.logger.info("Setting happn console permissions.", metadata: [
				LMK.users: .array(users.map{ .string(happnService.shortDescription(fromUser: $0)) }),
				LMK.permissions: "\(requestedPermissions)"
			])
		}
		
		let connector = happnService.connector
		try await connector.connect(["acl_create", "acl_update", "acl_read"])
		
		/* Set ACLs of user. */
		_ = try await users.map{ $0.id! /* We have filtered the users earlier for non-nil ids. */ }.concurrentMap{ userID in
			let operation = try URLRequestDataOperation<HappnApiResult<[HappnACL]>>.forAPIRequest(
				url: happnService.config.connectorSettings.baseURL.appending("api", "user-acls", userID),
				httpBody: ["permissions": requestedPermissions],
				bodyEncoder: FormURLEncodedEncoder(),
				requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
			)
			_ = try await operation.startAndGetResult()
		}
	}
	
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
