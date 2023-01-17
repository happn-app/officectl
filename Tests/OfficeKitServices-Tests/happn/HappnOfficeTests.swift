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
import OfficeKit
import ServiceKit
import URLRequestOperation

@testable import HappnOffice



final class HappnOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: String
			var userID: HappnUserID
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
		URLRequestOperationConfig.logHTTPResponses = true
		URLRequestOperationConfig.logHTTPRequests = true
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
	
	func testListAllUser() async throws {
		let allUsers = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: services)
		print(allUsers)
		XCTAssertGreaterThan(allUsers.count, 0)
	}
	
	func testGetUser() async throws {
		let optionalUser = try await service.existingUser(fromID: testConf.fetchedUser.userID, propertiesToFetch: nil, using: services)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.id)
	}
	
	func testGetUserWithNullID() async throws {
		let optionalUser = try await service.existingUser(fromID: .nullLogin, propertiesToFetch: nil, using: services)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, "244")
	}
	
	func testGetExistingUserFromPersistentID() async throws {
		let optionalUser = try await service.existingUser(fromPersistentID: testConf.fetchedUser.id, propertiesToFetch: nil, using: services)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_id, testConf.fetchedUser.userID)
		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.id)
	}
	
	func testGetNonExistingUserWithPersistentID() async throws {
		let optionalUser = try await service.existingUser(fromPersistentID: "42", propertiesToFetch: nil, using: services)
		XCTAssertNil(optionalUser)
	}
	
}
