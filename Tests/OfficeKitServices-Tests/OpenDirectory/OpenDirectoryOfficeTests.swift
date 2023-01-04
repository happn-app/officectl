/*
 * OpenDirectoryOfficeTests.swift
 * OpenDirectoryOfficeTests
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import OfficeKit2
import ServiceKit
import URLRequestOperation

@testable import OpenDirectoryOffice



final class OpenDirectoryOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: LDAPDistinguishedName
			var gid: UUID
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(OpenDirectoryServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: OpenDirectoryService!
	var testConf: TestConf!
	
	let services = Services()
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		URLRequestOperationConfig.logHTTPResponses = true
		URLRequestOperationConfig.logHTTPRequests = true
		confs = Result{ try parsedConf(for: "od") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = OpenDirectoryService(id: "test-od", openDirectoryServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testFetchUser() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.id, propertiesToFetch: nil, using: services)
		XCTAssertEqual(user?.oU_persistentID, testConf.fetchedUser.gid)
	}
	
}
