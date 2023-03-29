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
			var id: String
			var userPrincipalName: Email
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(Office365ServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: Office365Service!
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
		self.service = try Office365Service(id: "test-o365", name: "Tested Office 365 Service", office365ServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testConnection() async throws {
		let connector = try Office365Connector(
			tenantID: serviceConf.connectorSettings.tenantID,
			clientID: serviceConf.connectorSettings.clientID,
			grant: serviceConf.connectorSettings.grant
		)
		try await connector.connect(["https://graph.microsoft.com/.default"])
		let connected = await connector.isConnected
		XCTAssertTrue(connected)
	}
	
	func testFetchUserAll() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil)
		XCTAssertGreaterThan(users.count, 0)
	}
	
	func testGetUser() async throws {
		let optionalUser = try await service.existingUser(fromID: testConf.fetchedUser.userPrincipalName, propertiesToFetch: nil)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.id)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialEmailStr = "officectl.test.\((0..<42).randomElement()!)@happn.fr"
		let modifiedEmailStr = "officectl.test-modified.\((0..<42).randomElement()!)@happn.fr"
		
		var user = Office365User(oU_id: Email(rawValue: initialEmailStr)!)
		XCTAssertEqual(user.userPrincipalName, Email(rawValue: initialEmailStr))
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true)
		XCTAssertEqual(user.userPrincipalName, Email(rawValue: initialEmailStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		user = try await service.createUser(user)
		XCTAssertEqual(user.userPrincipalName, Email(rawValue: initialEmailStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		XCTAssertFalse(user.oU_setValue(modifiedEmailStr, forProperty: .emails, convertMismatchingTypes: false).propertyWasModified)
		XCTAssertTrue( user.oU_setValue(modifiedEmailStr, forProperty: .emails, convertMismatchingTypes: true ).propertyWasModified)
		
		/* We have to wait a bit because the user is not created immeditaly and if we try to update it we get an error. */
//		try await Task.sleep(nanoseconds: 13_000_000_000/*13s*/)
		
//		user = try await service.updateUser(user, propertiesToUpdate: [.emails])
//		XCTAssertEqual(user.userPrincipalName, Email(rawValue: modifiedEmailStr))
//		XCTAssertEqual(user.oU_firstName, "Officectl")
//		XCTAssertEqual(user.oU_lastName, "Test")
		
		try await service.deleteUser(user)
	}
	
}
