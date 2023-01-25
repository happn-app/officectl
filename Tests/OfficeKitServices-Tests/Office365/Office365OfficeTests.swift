/*
 * Office365OfficeTests.swift
 * Office365OfficeTests
 *
 * Created by François Lamboley on 2022/12/22.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import Logging
import OfficeKit
import URLRequestOperation

@testable import Office365Office



final class Office365OfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: UUID
			var login: String
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(Office365ServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
//	var service: Office365Service!
	var serviceConf: Office365ServiceConfig!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		confs = Result{ try parsedConf(for: "o365") }
	}
	
	override func setUp() async throws {
		try await super.setUp()

		let (serviceConf, testConf) = try Self.confs.get()

		self.testConf = testConf
		self.serviceConf = serviceConf
//		self.service = try Office365Service(id: "test-o365", name: "Tested Office 365 Service", office365ServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
//		service = nil
	}
	
	func testConnection() async throws {
		let connector = try Office365Connector(
			tenantID: serviceConf.connectorSettings.tenantID,
			clientID: serviceConf.connectorSettings.clientID,
			clientSecret: serviceConf.connectorSettings.clientSecret
//			privateKeyURL: URL(fileURLWithPath: serviceConf.connectorSettings.privateKeyPath, isDirectory: false)
		)
		try await connector.connect(["https://graph.microsoft.com/.default"])
		let connected = await connector.isConnected
		XCTAssertTrue(connected)
	}
	
}
