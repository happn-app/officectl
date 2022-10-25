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
		let dummyService = try DummyService(id: "dummy", jsonConfig: .null)
		var dictionaryOfServices = [DeportedHashability<any OfficeService>: String]()
		
		dictionaryOfServices[.init(value: dummyService, valueID: dummyService.id)] = value1
		XCTAssertEqual(dictionaryOfServices[dummyService], value1)
		
		dictionaryOfServices[dummyService] = value2
		XCTAssertEqual(dictionaryOfServices[dummyService], value2)
	}
	
	func testConvenienceDictionaryWithDeportedHashabilityOfUserServiceKeys() throws {
		let value1 = "yolo1", value2 = "yolo2"
		let dummyService = try DummyService(id: "dummy", jsonConfig: .null)
		var dictionaryOfServices = [DeportedHashability<any UserService>: String]()
		
		dictionaryOfServices[.init(value: dummyService, valueID: dummyService.id)] = value1
		XCTAssertEqual(dictionaryOfServices[dummyService], value1)
		
		dictionaryOfServices[dummyService] = value2
		XCTAssertEqual(dictionaryOfServices[dummyService], value2)
	}
	
}
