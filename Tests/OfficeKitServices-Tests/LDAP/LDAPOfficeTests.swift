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
import OfficeKit2
import ServiceKit
import URLRequestOperation

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
		URLRequestOperationConfig.logHTTPResponses = true
		URLRequestOperationConfig.logHTTPRequests = true
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
	
	func testFetchUserFromID() async throws {
		let user = try await service.existingUser(fromID: testConf.fetchedUser.dn, propertiesToFetch: [.firstName], using: services)
		XCTAssertNil(user?.oU_lastName)
		XCTAssertNotNil(user?.oU_firstName)
		XCTAssertEqual(user?.oU_id, testConf.fetchedUser.dn)
	}
	
}
