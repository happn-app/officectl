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
		guard let requestedPermissions = officectlOptions.conf?.misc.happnConsolePermGroups?[group] else {
			officectlOptions.logger.error("Unknown group “\(group)”; bailing.")
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
