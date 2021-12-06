/*
 * devtest_consoleperm.swift
 * officectl
 *
 * Created by François Lamboley on 05/02/2020.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ArgumentParser
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



struct ConsolepermCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "consoleperm",
		abstract: "Set happn console permission for a user depending on a group."
	)
	
	@OptionGroup
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Argument
	var usermail: String
	
	@ArgumentParser.Argument
	var group: String
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let sProvider = app.officeKitServiceProvider
		let eventLoop = try app.services.make(EventLoop.self)
		
		let hService: HappnService = try sProvider.getService(id: nil)
		let hConnector: HappnConnector = app.semiSingletonStore.semiSingleton(forKey: hService.config.connectorSettings)
		
		let permissions: String
		switch group {
			case "acquisition": permissions = "admin_search_user,all_device_read,all_order_read,analytics_read,geo_read,geo_write,countries_read"
			case "content":     permissions = ""
			case "data":        permissions = "admin_search_user,all_shop_read,countries_create,countries_delete,countries_read,countries_update,geo_read,geo_write,pack_create,pack_delete,pack_update,shop_write,segment_read"
			case "back-end":    permissions = "achievement_type_create,achievement_type_delete,achievement_type_update,admin_search_user,all_accepted_create,all_accepted_delete,all_accepted_read,all_achievement_create,all_achievement_delete,all_achievement_read,all_achievement_update,all_availability_create,all_availability_delete,all_availability_read,all_availability_update,all_blocked_create,all_blocked_delete,all_blocked_read,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_device_create,all_device_delete,all_device_read,all_device_update,all_image_create,all_image_delete,all_image_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_notification_create,all_notification_delete,all_notification_read,all_notification_update,all_order_create,all_order_delete,all_order_read,all_order_update,all_position_read,all_position_update,all_rejected_create,all_rejected_delete,all_rejected_read,all_report_create,all_report_delete,all_report_read,all_report_update,all_shop_read,all_social_create,all_social_delete,all_social_read,all_social_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_segment_read,all_user_update,analytics_read,application_setting_create,application_setting_delete,application_setting_read,application_setting_update,applications_create,applications_delete,applications_read,applications_update,countries_create,countries_delete,countries_read,countries_update,coupon_create,coupon_delete,coupon_read,coupon_update,credit_create,credit_delete,credit_read,credit_update,geo_read,geo_write,language_create,language_delete,language_update,locale_create,locale_delete,locale_update,moderator_create,moderator_delete,moderator_read,moderator_update,notification_type_create,notification_type_delete,notification_type_update,pack_create,pack_delete,pack_update,permission_read,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,report_type_create,report_type_delete,report_type_update,reported_conversation_read,segment_create,segment_delete,segment_read,segment_update,shop_write,subscription_type_create,subscription_type_delete,subscription_type_update,translation_create,translation_delete,translation_read,translation_update,user_ban,user_ban_bulk,user_create,user_mode_create,user_mode_delete,user_mode_update,user_unban"
			case "mobile":      permissions = "achievement_type_create,achievement_type_delete,achievement_type_update,admin_search_user,all_accepted_create,all_accepted_delete,all_accepted_read,all_achievement_create,all_achievement_delete,all_achievement_read,all_achievement_update,all_availability_create,all_availability_delete,all_availability_read,all_availability_update,all_blocked_create,all_blocked_delete,all_blocked_read,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_device_create,all_device_delete,all_device_read,all_device_update,all_image_create,all_image_delete,all_image_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_notification_create,all_notification_delete,all_notification_read,all_notification_update,all_order_create,all_order_delete,all_order_read,all_order_update,all_position_read,all_position_update,all_rejected_create,all_rejected_delete,all_rejected_read,all_report_create,all_report_delete,all_report_read,all_report_update,all_social_create,all_social_delete,all_social_read,all_social_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_update,analytics_read,application_setting_create,application_setting_delete,application_setting_read,application_setting_update,applications_create,applications_delete,applications_read,applications_update,countries_create,countries_delete,countries_read,countries_update,coupon_create,coupon_delete,coupon_read,coupon_update,credit_create,credit_delete,credit_read,credit_update,geo_read,geo_write,language_create,language_delete,language_update,locale_create,locale_delete,locale_update,moderator_create,moderator_delete,moderator_read,moderator_update,notification_type_create,notification_type_delete,notification_type_update,pack_create,pack_delete,pack_update,permission_read,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,report_type_create,report_type_delete,report_type_update,reported_conversation_read,subscription_type_create,subscription_type_delete,subscription_type_update,translation_create,translation_delete,translation_read,translation_update,user_ban,user_create,user_mode_create,user_mode_delete,user_mode_update,user_unban"
			case "crm":         permissions = "admin_search_user,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_order_read,all_user_update,analytics_read,countries_read,coupon_read,geo_read,moderator_create,moderator_delete,moderator_read,moderator_update,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,reported_conversation_read"
			case "ads":         permissions = "admin_search_user,all_device_read,all_order_read,analytics_read,geo_read,geo_write,countries_read"
			case "rh":          permissions = ""
			case "finance":     permissions = ""
			case "ops":         permissions = "achievement_type_create,achievement_type_delete,achievement_type_update,acl_create,acl_delete,acl_read,acl_update,admin_create,admin_delete,admin_read,admin_search_user,all_accepted_create,all_accepted_delete,all_accepted_read,all_achievement_create,all_achievement_delete,all_achievement_read,all_achievement_update,all_archive_create,all_archive_read,all_availability_create,all_availability_delete,all_availability_read,all_availability_update,all_blocked_create,all_blocked_delete,all_blocked_read,all_conversation_create,all_conversation_delete,all_conversation_read,all_conversation_reported_read,all_conversation_update,all_device_create,all_device_delete,all_device_read,all_device_update,all_image_create,all_image_delete,all_image_update,all_message_create,all_message_delete,all_message_read,all_message_update,all_notification_create,all_notification_delete,all_notification_read,all_notification_update,all_order_create,all_order_delete,all_order_read,all_order_update,all_position_read,all_position_update,all_rejected_create,all_rejected_delete,all_rejected_read,all_report_create,all_report_delete,all_report_read,all_report_update,all_shop_read,all_social_create,all_social_delete,all_social_read,all_social_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_segment_read,all_user_update,analytics_read,application_setting_create,application_setting_delete,application_setting_read,application_setting_update,applications_create,applications_delete,applications_read,applications_update,countries_create,countries_delete,countries_read,countries_update,coupon_create,coupon_delete,coupon_read,coupon_update,credit_create,credit_delete,credit_read,credit_update,geo_read,geo_write,language_create,language_delete,language_update,locale_create,locale_delete,locale_update,moderator_create,moderator_delete,moderator_read,moderator_update,notification_type_create,notification_type_delete,notification_type_update,pack_create,pack_delete,pack_update,permission_read,push_campaign_create,push_campaign_delete,push_campaign_read,push_campaign_update,report_type_create,report_type_delete,report_type_update,reported_conversation_read,segment_create,segment_delete,segment_read,segment_update,shop_write,subscription_type_create,subscription_type_delete,subscription_type_update,translation_create,translation_delete,translation_read,translation_update,user_ban,user_ban_bulk,user_create,user_mode_create,user_mode_delete,user_mode_update,user_unban"
			case "support":     permissions = "admin_search_user,all_archive_create,all_archive_read,all_image_create,all_image_delete,all_image_update,all_notification_read,all_order_read,all_order_update,all_recovery_token_create,all_recovery_token_read,all_report_read,all_report_update,all_subscription_create,all_subscription_delete,all_subscription_read,all_subscription_update,all_user_delete,all_user_update,all_videocall_read,analytics_read,credit_update,geo_read,moderator_create,moderator_delete,moderator_read,push_campaign_create,push_campaign_read,push_campaign_update,user_ban,user_ban_bulk,user_create,user_unban"
			case "ext-support": permissions = "admin_search_user,all_archive_create,all_archive_read,all_audiocall_read,all_image_create,all_image_delete,all_image_update,all_notification_read,all_order_read,all_order_update,all_recovery_token_create,all_recovery_token_read,all_report_read,all_report_update,all_user_delete,all_user_update,all_videocall_read,analytics_read,credit_update,geo_read,moderator_create,moderator_delete,moderator_read,push_campaign_create,push_campaign_read,push_campaign_update,user_ban,user_ban_bulk,user_create,user_unban"
			default: throw InvalidArgumentError(message: "Unknown group")
		}
		
		guard let user = try await hService.existingUser(fromUserId: usermail, propertiesToFetch: [], using: app.services) else {
			throw InvalidArgumentError(message: "No user found with the given email")
		}
		guard let userID = user.id.value else {
			throw InternalError(message: "no userid… (should not happen!)")
		}
		
		try await hConnector.connect(scope: Set(arrayLiteral: "acl_create", "acl_update", "acl_read"))
		
		let url = hService.config.connectorSettings.baseURL.appendingPathComponent("api").appendingPathComponent("user-acls").appendingPathComponent(userID)
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		
		var urlComponents = URLComponents(string: "https://example.com")!
		urlComponents.queryItems = [
			URLQueryItem(name: "permissions", value: permissions)
		]
		urlRequest.httpBody = Data(urlComponents.percentEncodedQuery!.utf8)
		
		let authenticatedURLRequest = try await hConnector.authenticate(request: urlRequest)
		
		let operation = URLRequestOperation(request: authenticatedURLRequest.result)
		let data = try await EventLoopFuture<Data>.future(from: operation, on: eventLoop, resultRetriever: { o -> Data in
			guard let data = o.fetchedData else {
				throw o.finalError ?? InternalError(message: "no data and no known error from the request")
			}
			return data
		}).get()
		app.console.print(String(data: data, encoding: .utf8) ?? data.reduce("", { $0 + String(format: "%02x", $1) }))
	}
	
}
