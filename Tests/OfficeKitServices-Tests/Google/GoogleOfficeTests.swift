/*
 * GoogleOfficeTests.swift
 * GoogleOfficeTests
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

@testable import GoogleOffice



final class GoogleOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var id: String
			var email: Email
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(GoogleServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: GoogleService!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		confs = Result{ try parsedConf(for: "google") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = try GoogleService(id: "test-gougle", name: "Tested Gougle Service", googleServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testGetUser() async throws {
		let optionalUser = try await service.existingUser(fromID: testConf.fetchedUser.email, propertiesToFetch: nil)
		let user = try XCTUnwrap(optionalUser)
		XCTAssertEqual(user.oU_persistentID, testConf.fetchedUser.id)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialEmailStr = "officectl.test.\((0..<42).randomElement()!)@happn.fr"
		let modifiedEmailStr = "officectl.test-modified.\((0..<42).randomElement()!)@happn.fr"
		
		var user = GoogleUser(oU_id: Email(rawValue: initialEmailStr)!)
		XCTAssertEqual(user.primaryEmail, Email(rawValue: initialEmailStr))
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test", UserProperty(rawValue: GoogleService.providerID + "/password"): String.generatePassword()], convertMismatchingTypes: true)
		XCTAssertEqual(user.primaryEmail, Email(rawValue: initialEmailStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		user = try await service.createUser(user)
		XCTAssertEqual(user.primaryEmail, Email(rawValue: initialEmailStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		XCTAssertFalse(user.oU_setValue(modifiedEmailStr, forProperty: .emails, convertMismatchingTypes: false).propertyWasModified)
		XCTAssertTrue( user.oU_setValue(modifiedEmailStr, forProperty: .emails, convertMismatchingTypes: true ).propertyWasModified)
		
		/* We have to wait a bit because the user is not created immeditaly and if we try to update it we get an error. */
		try await Task.sleep(nanoseconds: 13_000_000_000/*13s*/)
		
		user = try await service.updateUser(user, propertiesToUpdate: [.emails])
		XCTAssertEqual(user.primaryEmail, Email(rawValue: modifiedEmailStr))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		try await service.deleteUser(user)
	}
	
}
