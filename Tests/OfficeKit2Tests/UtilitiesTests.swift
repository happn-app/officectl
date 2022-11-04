/*
 * UtilitiesTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation
import XCTest
@testable import OfficeKit2



class UtilitiesTests : XCTestCase {
	
	func testConvenienceDictionaryWithDeportedHashabilityOfOfficeServiceKeys() throws {
		let value1 = "yolo1", value2 = "yolo2"
		let dummyService = try DummyService1(id: "dummy1", jsonConfig: .null)
		var dictionaryOfServices = [DeportedHashability<any OfficeService>: String]()
		
		dictionaryOfServices[.init(value: dummyService, valueID: dummyService.id)] = value1
		XCTAssertEqual(dictionaryOfServices[dummyService], value1)
		
		dictionaryOfServices[dummyService] = value2
		XCTAssertEqual(dictionaryOfServices[dummyService], value2)
	}
	
	func testConvenienceDictionaryWithDeportedHashabilityOfUserServiceKeys() throws {
		let value1 = "yolo1", value2 = "yolo2"
		let dummyService = try DummyService1(id: "dummy1", jsonConfig: .null)
		var dictionaryOfServices = [DeportedHashability<any UserService>: String]()
		
		dictionaryOfServices[.init(value: dummyService, valueID: dummyService.id)] = value1
		XCTAssertEqual(dictionaryOfServices[dummyService], value1)
		
		dictionaryOfServices[dummyService] = value2
		XCTAssertEqual(dictionaryOfServices[dummyService], value2)
	}
	
	func testUserIDBuilder1() throws {
		let user = SimpleUser1(id: "francois.lamboley@happn.fr", firstName: "François", lastName: "Lamboley")
		let builder = UserIDBuilder(format: "*|firstName|*.*|lastName|*@|domain|")
		XCTAssertThrowsError(try builder.inferID(fromUser: user))
		XCTAssertEqual(try builder.inferID(fromUser: user, additionalVariables: ["domain": "happn.fr"]), user.id)
	}
	
	func testUserIDBuilder2() throws {
		let user = SimpleUser1(id: "ipek.kucuk@happn.fr", firstName: "İpek", lastName: "Küçük")
		let builder = UserIDBuilder(format: "*|firstName|.|lastName|*@happn.fr")
		XCTAssertEqual(try builder.inferID(fromUser: user), user.id)
	}
	
	func testUserIDBuilder3() throws {
		let user = SimpleUser1(id: "thibault.le-cornec@happn.fr", firstName: "Thibault", lastName: "Le Cornec")
		let builder = UserIDBuilder(format: "*|firstName|.|lastName|*@happn.fr")
		XCTAssertEqual(try builder.inferID(fromUser: user), user.id)
	}
	
	func testUserIDBuilder4() throws {
		let user = SimpleUser1(id: "uid=francois.lamboley,ou=people,dc=happn,dc=com", firstName: "François", lastName: "Lamboley")
		let builder = UserIDBuilder(format: "?uid:|id|?@happn.fr")
		XCTAssertEqual(try builder.inferID(fromUser: user), "francois.lamboley@happn.fr")
	}
	
}
