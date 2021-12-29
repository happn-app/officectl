/*
 * ServicesProviderTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2019/08/17.
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
		let config = try! OfficeKitConfig(globalConfig: globalConf, serviceConfigs: [ldapConfForTests.erase(), fakeHappnConfig.erase()], authServiceId: ldapConfForTests.serviceId)
		servicesProvider = OfficeKitServiceProvider(config: config)
	}
	
	override func tearDown() {
		super.tearDown()
		
		servicesProvider = nil
	}
	
	func testFetchLDAPConf() throws {
		let _: LDAPService = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
	}
	
	func testFetchLDAPConfAsAnyUserDirectoryService() throws {
		let _: AnyUserDirectoryService = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
	}
	
	func testFetchLDAPConfAsAnyUserDirectoryServiceWithGetService() throws {
		/* The service has to be fetched once before with the correct type. */
		let _ = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
		let _: AnyUserDirectoryService = try servicesProvider.getService(id: ldapConfForTests.serviceId)
	}
	
	func testFetchLDAPConfAsGenericConfAndSpecificConfGivesEqualUnboxedObjects() throws {
		let s1: LDAPService = try servicesProvider.getService(id: ldapConfForTests.serviceId)
		let s2: LDAPService = try servicesProvider.getUserDirectoryService(id: ldapConfForTests.serviceId)
		XCTAssert(s1 === s2)
	}
	
}
