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
import OfficeKit2
import ServiceKit
import URLRequestOperation

@testable import GitHubOffice



final class GitHubOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
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
		self.service = try GitHubService(id: "test-github", gitHubServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testGetAllUsers() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: services)
		XCTAssertGreaterThan(users.count, 50)
	}
	
}
