/*
 * HappnOfficeTests.swift
 * HappnOfficeTests
 *
 * Created by François Lamboley on 2022/12/22.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import OfficeKit2
import ServiceKit

@testable import HappnOffice



final class HappnOfficeTests : XCTestCase {
	
	/* Parsed once for the whole test case. */
	static var conf: Result<HappnServiceConfig, Error>!
	
	/* A new instance of the service is created for each test. */
	var service: HappnService!
	
	let services = Services()
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		conf = Result{ try parsedConf(for: "happn") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let conf = try Self.conf.get()
		service = try HappnService(id: "test-happn", happnServiceConfig: conf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testGetUser() async throws {
		let id = Email(rawValue: "<REDACTED>")!
		let optionalUser = try await service.existingUser(fromID: id, propertiesToFetch: nil, using: services)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, "<REDACTED>")
	}
	
}
