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
		var dictionaryOfServices = [DeportedHashability<any OfficeService, String>: String]()
		
		dictionaryOfServices[.init(value: dummyService, valueID: dummyService.id)] = value1
		XCTAssertEqual(dictionaryOfServices[dummyService], value1)
		
		dictionaryOfServices[dummyService] = value2
		XCTAssertEqual(dictionaryOfServices[dummyService], value2)
	}
	
	func testConvenienceDictionaryWithDeportedHashabilityOfUserServiceKeys() throws {
		let value1 = "yolo1", value2 = "yolo2"
		let dummyService = try DummyService1(id: "dummy1", jsonConfig: .null)
		var dictionaryOfServices = [DeportedHashability<any UserService, String>: String]()
		
		dictionaryOfServices[.init(value: dummyService, valueID: dummyService.id)] = value1
		XCTAssertEqual(dictionaryOfServices[dummyService], value1)
		
		dictionaryOfServices[dummyService] = value2
		XCTAssertEqual(dictionaryOfServices[dummyService], value2)
	}
	
//	func testUsageMultiServicesItemUsage() throws {
//		let dummyUser1 = DummyUser1()
//		let dummyUser2 = DummyUser2()
//		let dummyService1 = try DummyService1(id: "dummy1", jsonConfig: .null)
//		let dummyService2 = try DummyService2(id: "dummy2", jsonConfig: .null)
//		let multiServiceItem = MultiServicesItem(errorsAndItemsByService: [
//			.init(dummyService1): .success(dummyUser1),
//			.init(dummyService2): .success(dummyUser2)
//		])
//	}
	
}
