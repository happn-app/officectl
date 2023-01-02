/*
 * UserUtilsTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2023/01/02.
 */

import Foundation
import XCTest

@testable import OfficeKit2



final class UserUtilsTests : XCTestCase {
	
	func testSetValueIfNeeded() throws {
		var value: String = "no"
		_ = DummyUser1.setValueIfNeeded("yes" as Any, in: &value, converter: { $0 as? String })
		XCTAssertEqual(value, "yes")
	}
	
	func testSetValueIfNeededOptional() throws {
		var value: String = "no"
		_ = DummyUser1.setValueIfNeeded("yes" as Any?, in: &value, converter: { $0 as? String })
		XCTAssertEqual(value, "yes")
	}
	
	func testSetValueIfNeededOptionalInvalidType() throws {
		var value: String? = "no"
		_ = DummyUser1.setValueIfNeeded(12 as Any, in: &value, converter: { $0 as? String })
		XCTAssertEqual(value, "no")
	}
	
	func testSetValueIfNeededOptionalNilValue() throws {
		var value: String? = "no"
		_ = DummyUser1.setValueIfNeeded(nil as Any?, in: &value, converter: { $0 as? String })
		XCTAssertEqual(value, nil)
	}
	
	func testSetValueIfNeededOptionalHiddenNilValue() throws {
		var value: String? = "no"
		_ = DummyUser1.setValueIfNeeded(Optional<Int>.none as Any, in: &value, converter: { $0 as? String })
		XCTAssertEqual(value, nil)
	}
	
}
