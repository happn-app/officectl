/*
 * EmailTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 23/03/2019.
 */

import XCTest
@testable import OfficeKit



class EmailTests : XCTestCase {
	
	func testSimpleEmail() {
		XCTAssertTrue(Email.isValidEmail("hello@happn.com", checkDNS: false) == .valid)
	}
	
}
