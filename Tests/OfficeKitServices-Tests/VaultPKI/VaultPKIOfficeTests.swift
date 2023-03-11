/*
 * VaultPKIOfficeTests.swift
 * VaultPKIOfficeTests
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation
import XCTest

import SwiftASN1

import CommonForOfficeKitServicesTests
import Logging
import OfficeKit
import URLRequestOperation

@testable import VaultPKIOffice



final class VaultPKIOfficeTests : XCTestCase {
	
	struct TestConf : Decodable {
	}
	
	/* Parsed once for the whole test case. */
	static var confs: Result<(VaultPKIServiceConfig, TestConf), Error>!
	
	/* A new instance of the service is created for each test. */
	var service: VaultPKIService!
	var testConf: TestConf!
	
	/* Why, oh why this is not throwing? idk. */
	override class func setUp() {
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		confs = Result{ try parsedConf(for: "vault") }
	}
	
	override func setUp() async throws {
		try await super.setUp()
		
		let (serviceConf, testConf) = try Self.confs.get()
		
		self.testConf = testConf
		self.service = VaultPKIService(id: "test-vault", name: "Tested VaultPKI Service", vaultPKIServiceConfig: serviceConf, workdir: nil)
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		service = nil
	}
	
	func testParseEmptyCRL() async throws {
		let crlURL = Self.testsDataPath.appendingPathComponent("other/apple-root.crl")
		let crlData = try Data(contentsOf: crlURL)
		let crlParsed = try ASN1CertificateList(derEncoded: DER.parse([UInt8](crlData)))
		XCTAssertEqual(crlParsed.tbsCertList.revokedCertificates?.count ?? 0, 0)
		XCTAssertNotNil(crlParsed.tbsCertList.crlExtensions)
		
		var serializer = DER.Serializer()
		try crlParsed.serialize(into: &serializer)
		XCTAssertEqual(Data(serializer.serializedBytes).reduce("", { $0 + String(format: "%02x", $1) }), crlData.reduce("", { $0 + String(format: "%02x", $1) }))
	}
	
	func testParseNonEmptyCRL() async throws {
		let crlURL = Self.testsDataPath.appendingPathComponent("other/apple-wwdrca.crl")
		let crlData = try Data(contentsOf: crlURL)
		let crlParsed = try ASN1CertificateList(derEncoded: DER.parse([UInt8](crlData)))
		XCTAssertEqual(crlParsed.tbsCertList.revokedCertificates?.count ?? 0, 56006)
		XCTAssertNotNil(crlParsed.tbsCertList.crlExtensions)
		
		var serializer = DER.Serializer()
		try crlParsed.serialize(into: &serializer)
		XCTAssertEqual(Data(serializer.serializedBytes), crlData)
	}
	
	func testGetUsers() async throws {
		let users = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil)
		XCTAssertGreaterThan(users.count, 0)
	}
	
	func testSuspendedUsers() async throws {
		let usersNoSuspended = try await service.listAllUsers(includeSuspended: false, propertiesToFetch: nil)
		let usersAll = try await service.listAllUsers(includeSuspended: true, propertiesToFetch: nil)
		/* We assume we’ll have at least one user suspended in prod. If not the test fails. */
		XCTAssertGreaterThan(usersAll.count, usersNoSuspended.count)
	}
	
}
