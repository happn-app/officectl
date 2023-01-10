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
		_ = DummyUser1.setProperty(&value, to: "yes" as Any, allowTypeConversion: true, converter: { $0 as? String })
		XCTAssertEqual(value, "yes")
	}
	
	func testSetValueIfNeededOptional() throws {
		var value: String = "no"
		_ = DummyUser1.setProperty(&value, to: "yes" as Any?, allowTypeConversion: true, converter: { $0 as? String })
		XCTAssertEqual(value, "yes")
	}
	
	func testSetValueIfNeededOptionalInvalidType() throws {
		var value: String? = "no"
		_ = DummyUser1.setOptionalProperty(&value, to: 12 as Any, allowTypeConversion: true, converter: { $0 as? String })
		XCTAssertEqual(value, "no")
	}
	
	func testSetValueIfNeededOptionalNilValue() throws {
		var value: String? = "no"
		_ = DummyUser1.setOptionalProperty(&value, to: nil as Any?, allowTypeConversion: true, converter: { $0 as? String })
		XCTAssertEqual(value, nil)
	}
	
	func testSetValueIfNeededOptionalHiddenNilValue() throws {
		var value: String? = "no"
		_ = DummyUser1.setOptionalProperty(&value, to: Optional<Int>.none as Any, allowTypeConversion: true, converter: { $0 as? String })
		XCTAssertEqual(value, "no") /* Optionality is hidden, so it does not pass the switch case in setValueIfNeeded, thus calling the converter on “none”. */
	}
	
}
