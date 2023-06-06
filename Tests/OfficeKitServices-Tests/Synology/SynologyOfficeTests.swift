/*
 * SynologyOfficeTests.swift
 * SynologyOfficeTests
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

@testable import SynologyOffice



final class SynologyOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		/*TODO*/
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(SynologyServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: SynologyService!
	var serviceConf: SynologyServiceConfig!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		bootstrapIfNeeded()
		confs = Result{ try parsedConf(for: "syno") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.serviceConf = serviceConf
		self.service = try SynologyService(id: "test-syno", name: "Tested Office 365 Service", synologyServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testConnection() async throws {
		let connector = try SynologyConnector(
			dsmURL: serviceConf.connectorSettings.dsmURL,
			username: serviceConf.connectorSettings.username,
			password: serviceConf.connectorSettings.password
		)
		try await connector.connect()
		let connected = await connector.isConnected
		XCTAssertTrue(connected)
		try await connector.disconnect()
	}
	
	func testFetchUserAll() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil)
		XCTAssertGreaterThan(users.count, 0)
	}
	
	func testGetUser() async throws {
//		let optionalUser = try await service.existingUser(fromID: testConf.fetchedUser.userPrincipalName, propertiesToFetch: nil)
//		let user = try XCTUnwrap(optionalUser)
//		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.id)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialEmailStr = "officectl.test.\((0..<42).randomElement()!)@happn.fr"
		let modifiedEmailStr = "officectl.test-modified.\((0..<42).randomElement()!)@happn.fr"
		
		var user = SynologyUser(oU_id: Email(rawValue: initialEmailStr)!)
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
		XCTAssertFalse(user.oU_setValue("Officectl",          forProperty: .firstName, convertMismatchingTypes: false).propertyWasModified)
		XCTAssertTrue( user.oU_setValue("Officectl Modified", forProperty: .firstName, convertMismatchingTypes: false).propertyWasModified)
		
		/* We have to wait a bit because the user is not created immeditaly and if we try to update it we get an error. */
//		try await Task.sleep(nanoseconds: 13_000_000_000/*13s*/)
		
		user = try await service.updateUser(user, propertiesToUpdate: [.emails])
		XCTAssertEqual(user.userPrincipalName, Email(rawValue: modifiedEmailStr))
		/* First name and last name are nil here as the M$ service will fully re-fetch the user after an update, with the properties to update.
		 * This is due to M$’s API not returning the user after an update. */
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		try await service.deleteUser(user)
	}
	
}
