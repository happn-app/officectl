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
	
	func testCloudFlareZeroTrustIDStringConversions() async throws {
		func testID(_ id: CloudflareZeroTrustUser.ID, _ expectedString: String, _ separator: String? = nil, _ escape: String? = nil) {
			XCTAssertEqual(id.rawValue(forcedSeparator: separator, forcedEscape: escape), expectedString)
			XCTAssertEqual(id, CloudflareZeroTrustUser.ID(rawValue: expectedString, forcedSeparator: separator, forcedEscape: escape))
		}
		testID(.init(cfSeatID: "123"), "123")
		testID(.init(cfSeatID: "123 #456"), "123 #/456")
		testID(.init(cfSeatID: "123", email: Email(rawValue: "a@example.org")!), "a@example.org #123")
		testID(.init(cfSeatID: "123", email: Email(rawValue: "abc#.def@example.org")!), "abc#.def@example.org#.123", "#.")
		testID(.init(cfSeatID: "123#.456", email: Email(rawValue: "abc#.def#.ghi@example.org")!), "abc#.def#.ghi@example.org#.123#.%*456", "#.", "%*")
	}
	
}
