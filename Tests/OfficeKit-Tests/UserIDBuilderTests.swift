/*
 * UserIDBuilderTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation
import XCTest

@testable import OfficeKit



final class UserIDBuilderTests : XCTestCase {
	
	func testUserIDBuilder1() throws {
		let user = SimpleUser1(oU_id: "francois.lamboley@happn.fr", oU_firstName: "François", oU_lastName: "Lamboley")
		let builder = UserIDBuilder(format: "*|first_name|*.*|last_name|*@|domain|")
		XCTAssertNil(builder.inferID(fromUser: user))
		XCTAssertEqual(builder.inferID(fromUser: user, additionalVariables: ["domain": "happn.fr"]), user.oU_id)
	}
	
	func testUserIDBuilder2() throws {
		let user = SimpleUser1(oU_id: "ipek.kucuk@happn.fr", oU_firstName: "İpek", oU_lastName: "Küçük")
		let builder = UserIDBuilder(format: "*|first_name|.|last_name|*@happn.fr")
		XCTAssertEqual(builder.inferID(fromUser: user), user.oU_id)
	}
	
	func testUserIDBuilder3() throws {
		let user = SimpleUser1(oU_id: "thibault.le-cornec@happn.fr", oU_firstName: "Thibault", oU_lastName: "Le Cornec")
		let builder = UserIDBuilder(format: "*|first_name|.|last_name|*@happn.fr")
		XCTAssertEqual(builder.inferID(fromUser: user), user.oU_id)
	}
	
	func testUserIDBuilder4() throws {
		let user = try SimpleUser1(oU_id: DistinguishedName(string: "uid=francois.lamboley,ou=people,dc=happn,dc=com"), oU_firstName: "François", oU_lastName: "Lamboley")
		let builder = UserIDBuilder(format: "?id:uid?@happn.fr")
		XCTAssertEqual(builder.inferID(fromUser: user), "francois.lamboley@happn.fr")
	}
	
}
