/*
 * LDAPOfficeTests.swift
 * LDAPOfficeTests
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import Logging
import OfficeKit2
import ServiceKit
import URLRequestOperation

@testable import LDAPOffice



final class LDAPOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: String
			var gid: UUID
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(LDAPServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: LDAPService!
	var testConf: TestConf!
	
	let services = Services()
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		LDAPOfficeConfig.logger = Logger(label: "test-ldap")
		LDAPOfficeConfig.logger?.logLevel = .trace
		URLRequestOperationConfig.logHTTPResponses = true
		URLRequestOperationConfig.logHTTPRequests = true
		confs = Result{ try parsedConf(for: "ldap") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = LDAPService(id: "test-ldap", LDAPServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testFetchUserFromID() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.id, propertiesToFetch: nil, using: services)
		XCTAssertNotNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
		XCTAssertEqual(user?.oU_persistentID, testConf.fetchedUser.gid)
	}
	
	func testFetchPartialUserFromID() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.id, propertiesToFetch: [.firstName], using: services)
		XCTAssertNotNil(user)
		XCTAssertNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
	}
	
	func testFetchUserFromPersistentID() async throws {
		let user = try await service.existingUser(fromPersistentID: testConf.fetchedUser.gid, propertiesToFetch: nil, using: services)
		XCTAssertEqual(user?.oU_id, testConf.fetchedUser.id)
	}
	
	func testFetchPartialUserFromPersistentID() async throws {
		let user = try await service.existingUser(fromPersistentID: testConf.fetchedUser.gid, propertiesToFetch: [.firstName], using: services)
		XCTAssertNotNil(user)
		XCTAssertNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
	}
	
	func testListAllUsers() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: services)
		XCTAssertGreaterThan(users.count, 0)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialID = "officectl.test.\((0..<42).randomElement()!)"
		let modifiedID = "officectl.test-modified.\((0..<42).randomElement()!)"
		
		var user = LDAPUser(oU_id: initialID)
		XCTAssertEqual(user.id, initialID)
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test", .password: String.generatePassword()], allowIDChange: false, convertMismatchingTypes: true)
		XCTAssertEqual(user.id, initialID)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		user = try await service.createUser(user, using: services)
		XCTAssertEqual(user.id, initialID)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		XCTAssertTrue(user.oU_setValue("Test Modified", forProperty: .lastName, allowIDChange: true, convertMismatchingTypes: true))
		XCTAssertFalse(user.oU_setValue(modifiedID, forProperty: .id, allowIDChange: false, convertMismatchingTypes: true))
		XCTAssertTrue(user.oU_setValue(modifiedID, forProperty: .id, allowIDChange: true, convertMismatchingTypes: false))
		
		let testEmailStrs = ["officectl.test.1@invalid.happn.fr", "officectl.test.2@invalid.happn.fr"]
		XCTAssertTrue(user.oU_setValue(testEmailStrs, forProperty: .emails, allowIDChange: true, convertMismatchingTypes: true))
		
		user = try await service.updateUser(user, propertiesToUpdate: [.emails, .lastName], using: services)
		XCTAssertEqual(user.id, initialID)
		XCTAssertEqual(user.oU_emails?.map(\.rawValue), testEmailStrs)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test Modified")
		
		try await service.deleteUser(user, using: services)
	}
	
	func testCreateUpdateIDDeleteUser() async throws {
		let initialID = "officectl.test.\((0..<42).randomElement()!)"
		let modifiedID = "officectl.test-modified.23"
		
		var user = LDAPUser(oU_id: initialID)
		XCTAssertEqual(user.id, initialID)
		
		user = try await service.createUser(user, using: services)
		XCTAssertEqual(user.id, initialID)
		
		XCTAssertTrue(user.oU_setValue(modifiedID, forProperty: .id, allowIDChange: true, convertMismatchingTypes: true))
		XCTAssertEqual(user.id, modifiedID)
		
		/* So changing the ID of a user is not unsupported per se in Open Directory, but with our instance, it fails (with a cryptic error, of course: “Connection failed to the directory server.”) */
		let result = await Result{ try await service.updateUser(user, propertiesToUpdate: [.id], using: services) }
		XCTAssertThrowsError(try result.get())
		
		/* The update fails, but the user does not revert back to the server values. */
		XCTAssertEqual(user.id, modifiedID)
		
		try await service.deleteUser(user, using: services)
	}
	
}
