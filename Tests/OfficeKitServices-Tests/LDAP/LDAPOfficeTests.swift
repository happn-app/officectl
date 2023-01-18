/*
 * LDAPOfficeTests.swift
 * LDAPOfficeTests
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation
import XCTest

import CommonForOfficeKitServicesTests
import Email
import Logging
import OfficeKit
import ServiceKit

@testable import LDAPOffice



final class LDAPOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
		var caCerts: String?
		var fetchedUser: FetchedUser
		struct FetchedUser : Decodable {
			var dn: LDAPDistinguishedName
		}
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(LDAPServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: LDAPService!
	var testConf: TestConf!
	
	let services = Services()
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		LDAPOfficeConfig.logger = Logger(label: "test-ldap")
		LDAPOfficeConfig.logger?.logLevel = .trace
		confs = Result{
			let ret: (LDAPServiceConfig, TestConf) = try parsedConf(for: "ldap")
			if let path = ret.1.caCerts {
				try LDAPConnector.setCA(path)
			}
			return ret
		}
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = LDAPService(id: "test-ldap", ldapServiceConfig: serviceConf)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testFetchUserAll() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: services)
		XCTAssertGreaterThan(users.count, 0)
	}
	
	func testFetchUserFromID() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.dn, propertiesToFetch: [.firstName], using: services)
		XCTAssertNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
		XCTAssertEqual(user?.oU_id, testConf.fetchedUser.dn)
	}
	
	func testCreateUpdateDeleteUser() async throws {
		let initialDNString = "uid=officectl.test.\((0..<42).randomElement()!),\(service.config.peopleDN),\(service.config.baseDN)"
		let modifiedDNString = "uid=officectl.test-modified.\((0..<42).randomElement()!),\(service.config.peopleDN),\(service.config.baseDN)"
		
		var user = LDAPObject(oU_id: try LDAPDistinguishedName(string: initialDNString))
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNString))
		XCTAssertNil(user.oU_firstName)
		XCTAssertNil(user.oU_lastName)
		
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNString))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		print("Creating user...")
		user = try await service.createUser(user, using: services)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNString))
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test")
		
		XCTAssertTrue( user.oU_setValue("Test Modified", forProperty: .lastName, convertMismatchingTypes: true).propertyWasModified)
		XCTAssertFalse(user.oU_setValue("Test Modified", forProperty: .lastName, convertMismatchingTypes: true).propertyWasModified)
		XCTAssertFalse(user.oU_setValue(modifiedDNString, forProperty: .id,  convertMismatchingTypes: false).propertyWasModified)
		
		let testEmailStrs = ["officectl.test.1@invalid.happn.fr", "officectl.test.2@invalid.happn.fr"]
		XCTAssertTrue(user.oU_setValue(testEmailStrs, forProperty: .emails, convertMismatchingTypes: true).propertyWasModified)
		
		print("Updating user...")
		user = try await service.updateUser(user, propertiesToUpdate: [.emails, .lastName], using: services)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNString))
		XCTAssertEqual(user.oU_emails?.map(\.rawValue), testEmailStrs)
		XCTAssertEqual(user.oU_firstName, "Officectl")
		XCTAssertEqual(user.oU_lastName, "Test Modified")
		
		print("Deleting user...")
		try await service.deleteUser(user, using: services)
	}
	
	func testCreateUpdateIDDeleteUser() async throws {
		let initialDNString = "uid=officectl.test.\((0..<42).randomElement()!),\(service.config.peopleDN),\(service.config.baseDN)"
		let modifiedDNString = "uid=officectl.test-modified.\((0..<42).randomElement()!),\(service.config.peopleDN),\(service.config.baseDN)"
		
		var user = LDAPObject(oU_id: try LDAPDistinguishedName(string: initialDNString))
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNString))
		
		/* First name and or last name are mandatory for an LDAP user… */
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true)
		
		print("Creating user...")
		user = try await service.createUser(user, using: services)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: initialDNString))
		
		XCTAssertTrue(user.oU_setValue(modifiedDNString, forProperty: .id, convertMismatchingTypes: true).propertyWasModified)
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: modifiedDNString))
		
		/* Changing the DN of an LDAP record is not possible AFAIK (see oU_setValue implementation in LDAPObject). */
		print("Updating user...")
		let result = await Result{ try await service.updateUser(user, propertiesToUpdate: [.id], using: services) }
		XCTAssertThrowsError(try result.get())
		
		/* The update fails, but the user does not revert back to the server values. */
		XCTAssertEqual(user.id, try LDAPDistinguishedName(string: modifiedDNString))
		
		/* We have to change the ID back to be able to delete the user. */
		XCTAssertTrue(user.oU_setValue(initialDNString, forProperty: .id, convertMismatchingTypes: true).propertyWasModified)
		
		print("Deleting user...")
		try await service.deleteUser(user, using: services)
	}
	
	func testCreateUpdateCustomPropSSHKeyAndDeleteUser() async throws {
		let dn = try LDAPDistinguishedName(string: "uid=officectl.test.\((0..<42).randomElement()!),\(service.config.peopleDN),\(service.config.baseDN)")
		
		var user = LDAPObject(oU_id: dn)
		/* It seems first name and last name are mandatory. */
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true)
		
		print("Creating user...")
		user = try await service.createUser(user, using: services)
		
		let property = UserProperty(rawValue: "happn/ldap:custom-attribute:ldapPublicKey:sshPublicKey")
		user.oU_applyHints([property: "ssh-rsa yolo"], convertMismatchingTypes: true)
		
		print("Updating user...")
		user = try await service.updateUser(user, propertiesToUpdate: [property], using: services)
		
		print("Deleting user...")
		try await service.deleteUser(user, using: services)
	}
	
	func testCreateUpdateCustomPropGitHubIDAndDeleteUser() async throws {
		let dn = try LDAPDistinguishedName(string: "uid=officectl.test.\((0..<42).randomElement()!),\(service.config.peopleDN),\(service.config.baseDN)")
		
		var user = LDAPObject(oU_id: dn)
		/* It seems first name and last name are mandatory. */
		user.oU_applyHints([.firstName: "Officectl", .lastName: "Test"], convertMismatchingTypes: true)
		
		print("Creating user...")
		user = try await service.createUser(user, using: services)
		
		let property = UserProperty(rawValue: "happn/ldap:custom-attribute:happnObject:gitHubID")
		user.oU_applyHints([property: "Frizlab"], convertMismatchingTypes: true)
		
		print("Updating user...")
		user = try await service.updateUser(user, propertiesToUpdate: [property], using: services)
		
		print("Deleting user...")
		try await service.deleteUser(user, using: services)
	}
	
}
