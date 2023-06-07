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
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var name: String
			var uid: Int
		}
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
		self.service = try SynologyService(id: "test-syno", name: "Tested Synology Service", synologyServiceConfig: serviceConf, workdir: nil)
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
	
	func testGetUserFromUID() async throws {
		let optionalUser = try await service.existingUser(fromPersistentID: testConf.fetchedUser.uid, propertiesToFetch: nil)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_id, testConf.fetchedUser.name)
	}
	
	func testGetUserFromName() async throws {
		let optionalUser = try await service.existingUser(fromID: testConf.fetchedUser.name, propertiesToFetch: nil)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.uid)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialID = "officectl.test.\((0..<42).randomElement()!)"
		let modifiedID = "officectl.test-modified.\((0..<42).randomElement()!)"
		
		var user = SynologyUser(oU_id: initialID)
		XCTAssertEqual(user.name, initialID)
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		XCTAssertTrue(user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true).isEmpty)
		XCTAssertEqual(user.name, initialID)
		XCTAssertEqual(user.oU_firstName, nil)
		XCTAssertEqual(user.oU_lastName, nil)
		
		user = try await service.createUser(user)
		XCTAssertEqual(user.name, initialID)
		XCTAssertEqual(user.oU_firstName, nil)
		XCTAssertEqual(user.oU_lastName, nil)
		
		XCTAssertFalse(user.oU_setValue(modifiedID + "@happn.fr", forProperty: .emails, convertMismatchingTypes: false).propertyWasModified)
		XCTAssertTrue (user.oU_setValue(modifiedID + "@happn.fr", forProperty: .emails, convertMismatchingTypes: true ).propertyWasModified)
		
		user = try await service.updateUser(user, propertiesToUpdate: [.emails])
		XCTAssertEqual(user.email, Email(rawValue: modifiedID + "@happn.fr")!)
		
		try await service.deleteUser(user)
	}
	
}
