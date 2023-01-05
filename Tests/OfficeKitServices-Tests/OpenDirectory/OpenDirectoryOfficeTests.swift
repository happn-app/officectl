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
		OpenDirectoryOfficeConfig.logger = Logger(label: "test-od")
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
		let initialDNStr = "uid=officectl.test.\((0..<42).randomElement()!),cn=users,dc=od1,dc=happn,dc=private"
		let modifiedDNStr = "uid=officectl.test-modified.\((0..<42).randomElement()!),cn=users,dc=od1,dc=happn,dc=private"
		
		var user = OpenDirectoryUser(oU_id: try LDAPDistinguishedName(string: initialDNStr))
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNStr))
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test", .password: String.generatePassword()], allowIDChange: false, convertMismatchingTypes: true)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		user = try await service.createUser(user, using: services)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		XCTAssertFalse(user.oU_setValue(modifiedDNStr, forProperty: .id, allowIDChange: false, convertMismatchingTypes: true))
		XCTAssertFalse(user.oU_setValue(modifiedDNStr, forProperty: .id, allowIDChange: true, convertMismatchingTypes: false))
		XCTAssertTrue(user.oU_setValue(modifiedDNStr, forProperty: .id, allowIDChange: true, convertMismatchingTypes: true))
		
		let testEmailStrs = ["officectl.test.1@invalid.happn.fr", "officectl.test.2@invalid.happn.fr"]
		XCTAssertTrue(user.oU_setValue(testEmailStrs, forProperty: .emails, allowIDChange: true, convertMismatchingTypes: true))
		
		user = try await service.updateUser(user, propertiesToUpdate: [.id, .emails], using: services)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: modifiedDNStr))
		XCTAssertEqual(user.oU_emails?.map(\.rawValue), testEmailStrs)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		try await service.deleteUser(user, using: services)
	}
	
}
