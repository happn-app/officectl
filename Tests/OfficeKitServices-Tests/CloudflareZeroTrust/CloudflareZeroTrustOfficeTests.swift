/*
 * CloudflareZeroTrustOfficeTests.swift
 * CloudflareZeroTrustOfficeTests
 *
 * Created by François Lamboley on 2023/07/21.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import Logging
import OfficeKit
import URLRequestOperation

@testable import CloudflareZeroTrustOffice



final class CloudflareZeroTrustOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: User
		var existingUserNotPartOfHappn: User
		var userToAddAndRemove: User
		struct User : Decodable {
			var id: Int
			var login: String
		}
	}
	
	/* Parsed once for the whole test case. */
//	static var confs: Result<(CloudflareZeroTrustServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
//	var service: CloudflareZeroTrustService!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		bootstrapIfNeeded()
//		confs = Result{ try parsedConf(for: "cloudflare-zerotrust") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
//		let (serviceConf, testConf) = try Self.confs.get()
		
//		self.testConf = testConf
//		self.service = try CloudflareZeroTrustService(id: "test-cloudflare-zerotrust", name: "Tested Cloudflare ZeroTrust Service", cloudflareZeroTrustServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
//		service = nil
	}
	
	func testNothing() async throws {
	}
	
}
