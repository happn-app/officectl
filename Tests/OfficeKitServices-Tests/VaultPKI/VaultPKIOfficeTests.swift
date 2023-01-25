/*
 * VaultPKIOfficeTests.swift
 * VaultPKIOfficeTests
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Logging
import OfficeKit
import URLRequestOperation

@testable import VaultPKIOffice



final class VaultPKIOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(VaultPKIServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
//	var service: VaultPKIService!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		confs = Result{ try parsedConf(for: "vault") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
//		self.service = try VaultPKIService(id: "test-vault", name: "Tested VaultPKI Service", vaultPKIServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
//		service = nil
	}
	
	func testGetUsers() async throws {
//		let optionalUser = try await service.existingUser(fromPersistentID: testConf.fetchedUser.id, propertiesToFetch: nil)
//		let user = try XCTUnwrap(optionalUser)
//		XCTAssertEqual(user.login, testConf.fetchedUser.login)
	}
	
}
