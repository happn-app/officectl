/*
 * ServicesProviderTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 17/08/2019.
 */

import Foundation
import XCTest
@testable import OfficeKit



class ServicesProviderTests : XCTestCase {
	
	var servicesProvider: OfficeKitServiceProvider!
	
	override func setUp() {
		super.setUp()
		
		let fakeHappnConfig = HappnServiceConfig(
			providerId: HappnService.providerId,
			serviceId: "hppn",
			serviceName: "happn",
			mergePriority: nil,
			connectorSettings: HappnConnector.Settings(baseURL: URL(string: "https://happn.invalid")!, clientId: "fake", clientSecret: "fake", username: "fake@example.org", password: "fake")
		)
		let config = try! OfficeKitConfig(globalConfig: globalConf, serviceConfigs: [ldapConfForTests.erased(), fakeHappnConfig.erased()], authServiceId: ldapConfForTests.serviceId)
		servicesProvider = OfficeKitServiceProvider(config: config)
	}
	
	override func tearDown() {
		super.tearDown()
		
		servicesProvider = nil
	}
	
	func testFetchLDAPConf() throws {
		let _: LDAPService = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
	}
	
	func testFetchLDAPConfAsAny() throws {
		let _: AnyUserDirectoryService = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
	}
	
	func testFetchLDAPConfAsGenericConfAndSpecificConfGivesEqualUnboxedObjects() throws {
		let s1: LDAPService = try servicesProvider.getService(id: ldapConfForTests.serviceId)
		let s2: LDAPService = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
		XCTAssert(s1 === s2)
	}
	
}
