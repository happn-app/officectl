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
		
		let config = try! OfficeKitConfig(globalConfig: globalConf, serviceConfigs: [ldapConfForTests.erased()], authServiceId: ldapConfForTests.serviceId)
		servicesProvider = OfficeKitServiceProvider(config: config)
	}
	
	override func tearDown() {
		super.tearDown()
		
		servicesProvider = nil
	}
	
	func testFetchLDAPConf() {
		do {
			let _: LDAPService = try servicesProvider.getDirectoryService(id: ldapConfForTests.serviceId)
		} catch {
			XCTFail("Cannot fetch LDAP service with id")
		}
	}
	
	func testFetchLDAPConfAsAny() {
		do {
			let _: AnyDirectoryService = try servicesProvider.getDirectoryService(id: ldapConfForTests.serviceId)
		} catch {
			XCTFail("Cannot fetch erased LDAP service with id")
		}
	}
	
}
