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
import Logging
import OfficeKit
import UnwrapOrThrow
import URLRequestOperation

@testable import OpenDirectoryOffice



final class OpenDirectoryOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: String
			var gid: UUID
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(OpenDirectoryServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: OpenDirectoryService!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		bootstrapIfNeeded()
		
		OpenDirectoryOfficeConfig.logger = Logger(label: "test-od")
		OpenDirectoryOfficeConfig.logger?.logLevel = .trace
		
		confs = Result{ try parsedConf(for: "od") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = OpenDirectoryService(id: "test-od", name: "Tested OpenDirectory Service", openDirectoryServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testListAllUsers() async throws {
		let allUsers = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil)
		XCTAssertGreaterThan(allUsers.count, 0)
	}
	
	func testFetchUserFromID() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.id, propertiesToFetch: nil)
		XCTAssertNotNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
		XCTAssertEqual(user?.oU_persistentID, testConf.fetchedUser.gid)
	}
	
	func testFetchPartialUserFromID() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.id, propertiesToFetch: [.firstName])
		XCTAssertNotNil(user)
		XCTAssertNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
	}
	
	func testFetchUserFromPersistentID() async throws {
		let user = try await service.existingUser(fromPersistentID: testConf.fetchedUser.gid, propertiesToFetch: nil)
		XCTAssertEqual(user?.oU_id, testConf.fetchedUser.id)
	}
	
	func testFetchPartialUserFromPersistentID() async throws {
		let user = try await service.existingUser(fromPersistentID: testConf.fetchedUser.gid, propertiesToFetch: [.firstName])
		XCTAssertNotNil(user)
		XCTAssertNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialID = "officectl.test.\((0..<42).randomElement()!)"
		let modifiedID = "officectl.test-modified.\((0..<42).randomElement()!)"
		
		var user = OpenDirectoryUser(oU_id: initialID)
		XCTAssertEqual(user.id, initialID)
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true)
		XCTAssertEqual(user.id, initialID)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		user = try await service.createUser(user)
		XCTAssertEqual(user.id, initialID)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		XCTAssertTrue(user.oU_setValue("Test Modified", forProperty: .lastName, convertMismatchingTypes: true).propertyWasModified)
		XCTAssertTrue(user.oU_setValue(modifiedID, forProperty: .id, convertMismatchingTypes: false).propertyWasModified)
		
		let testEmailStrs = ["officectl.test.1@invalid.happn.fr", "officectl.test.2@invalid.happn.fr"]
		XCTAssertTrue(user.oU_setValue(testEmailStrs, forProperty: .emails, convertMismatchingTypes: true).propertyWasModified)
		
		user = try await service.updateUser(user, propertiesToUpdate: [.emails, .lastName])
		XCTAssertEqual(user.id, initialID)
		XCTAssertEqual(user.oU_emails?.map(\.rawValue), testEmailStrs)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test Modified")
		
		try await service.deleteUser(user)
	}
	
	func testCreateUpdateIDDeleteUser() async throws {
		let initialID = "officectl.test.\((0..<42).randomElement()!)"
		let modifiedID = "officectl.test-\((0..<42).randomElement()!)"
		
		var user = OpenDirectoryUser(oU_id: initialID)
		XCTAssertEqual(user.id, initialID)
		
		print("Creating user...")
		user = try await service.createUser(user)
		XCTAssertEqual(user.id, initialID)
		
		XCTAssertTrue(user.oU_setValue(modifiedID, forProperty: .id, convertMismatchingTypes: true).propertyWasModified)
		XCTAssertEqual(user.id, modifiedID)
		
		/* So changing the ID of a user is not unsupported per se in Open Directory,
		 *  but with our instance, it fails (with a cryptic error, of course: “Connection failed to the directory server.”).
		 * We have fully disabled modifying the record name of an entry now because it brought other issues (see “OpenDirectoryServices.swift”). */
		print("Updating user...")
		let result = await Result{ try await service.updateUser(user, propertiesToUpdate: [.id]) }
		XCTAssertThrowsError(try result.get())
		
		/* The update fails, but the user does not revert back to the server values. */
		XCTAssertEqual(user.id, modifiedID)
		
		print("Deleting user...")
		try await service.deleteUser(user)
	}
	
}
