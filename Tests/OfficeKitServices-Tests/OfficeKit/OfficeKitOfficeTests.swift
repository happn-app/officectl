/*
 * OfficeKitOfficeTests.swift
 * OfficeKitOfficeTests
 *
 * Created by François Lamboley on 2023/01/09.
 * 
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Logging

@testable import OfficeKitOffice



final class OfficeKitOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(OfficeKitServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: OfficeKitService!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		bootstrapIfNeeded()
		
		OfficeKitOfficeConfig.logger = Logger(label: "test-officekit")
		OfficeKitOfficeConfig.logger?.logLevel = .trace
		
		confs = Result{ try parsedConf(for: "officekit") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = OfficeKitService(id: "test-officekit", name: "Tested OfficeKit Service", officeKitServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testNothing() async throws {
	}
	
}
