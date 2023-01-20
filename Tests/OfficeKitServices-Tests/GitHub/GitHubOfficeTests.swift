/*
 * GitHubOfficeTests.swift
 * GitHubOfficeTests
 *
 * Created by François Lamboley on 2022/12/22.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import Logging
import OfficeKit
import ServiceKit
import URLRequestOperation

@testable import GitHubOffice



final class GitHubOfficeTests : XCTestCase {
	
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
	static var confs: Result<(GitHubServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: GitHubService!
	var testConf: TestConf!
	
	let services = Services()
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		URLRequestOperationConfig.logHTTPResponses = true
		URLRequestOperationConfig.logHTTPRequests = true
		confs = Result{ try parsedConf(for: "github") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = try GitHubService(id: "test-github", name: "Tested GitHub Service", gitHubServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testGetUser() async throws {
		let optionalUser = try await service.existingUser(fromPersistentID: testConf.fetchedUser.id, propertiesToFetch: nil, using: services)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.login, testConf.fetchedUser.login)
	}
	
	func testGetExistingUserNotPartOfHappn() async throws {
		let user = try await service.existingUser(fromPersistentID: testConf.existingUserNotPartOfHappn.id, propertiesToFetch: nil, using: services)
		XCTAssertNil(user)
	}
	
	func testGetAllUsers() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: services)
		XCTAssertGreaterThan(users.count, 50)
	}
	
	func testCreateAndDeleteUser() async throws {
		var user = GitHubUser(login: testConf.userToAddAndRemove.login)
		user = try await service.createUser(user, using: services)
		print("*** User is invited.")
		try await Task.sleep(nanoseconds: 1_000_000_000) /* Not necessarily required, but feels like a good thing. */
		try await service.deleteUser(user, using: services)
		print("*** Membership has been removed.")
	}
	
}
