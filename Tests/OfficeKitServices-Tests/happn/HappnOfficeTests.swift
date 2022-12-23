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
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: String
			var email: Email
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(HappnServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: HappnService!
	var testConf: TestConf!
	
	let services = Services()
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		confs = Result{ try parsedConf(for: "happn") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = try HappnService(id: "test-happn", happnServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testGetUser() async throws {
		let optionalUser = try await service.existingUser(fromID: testConf.fetchedUser.email, propertiesToFetch: nil, using: services)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.id)
	}
	
}
