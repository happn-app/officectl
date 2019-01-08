/*
 * LDAPOperationTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 03/01/2019.
 */

import XCTest
@testable import OfficeKit



/* Tests must run IN THE CORRECT ORDER (test1, test2, etc.). You must run
 * ./Scripts/start_tests_helpers.sh before starting the tests. */
class LDAPOperationTests : XCTestCase {
	
	static let baseDN = try! LDAPDistinguishedName(string: "dc=happn,dc=test")
	let baseDN = LDAPOperationTests.baseDN
	let ldapSettings = LDAPConnector.Settings(ldapURL: URL(string: "ldap://localhost:8389")!, protocolVersion: .v3, username: "cn=admin," + LDAPOperationTests.baseDN.stringValue, password: "toto")
	
	func test1_LDAPObjectCreation() throws {
		let connector = try getConnectedLDAPConnector()
		
		let op1 = CreateLDAPObjectsOperation(users: [LDAPInetOrgPerson(dn: LDAPDistinguishedName(uid: "test1", baseDN: baseDN).stringValue, sn: ["1"], cn: ["test 1"])], connector: connector)
		try runOperationSync(op1)
		XCTAssertEqual(try op1.resultOrThrow().count, 1)
		XCTAssertEqual(op1.errors.count, 1)
		XCTAssertNil(op1.errors[0])
		
		let op2 = CreateLDAPObjectsOperation(users: [LDAPInetOrgPerson(dn: LDAPDistinguishedName(uid: "test2", baseDN: baseDN).stringValue, sn: ["2"], cn: ["test 2"]), LDAPInetOrgPerson(dn: LDAPDistinguishedName(uid: "test1", baseDN: baseDN).stringValue, sn: ["1"], cn: ["test 1"])], connector: connector)
		try runOperationSync(op2)
		XCTAssertEqual(try op2.resultOrThrow().count, 1)
		XCTAssertEqual(op2.errors.count, 2)
		XCTAssertNil(op2.errors[0])
		XCTAssertNotNil(op2.errors[1])
	}
	
	func test2_LDAPObjectRetrieval() throws {
		let connector = try getConnectedLDAPConnector()
		
		let op1 = SearchLDAPOperation(ldapConnector: connector, request: LDAPSearchRequest(scope: .children, base: baseDN, searchQuery: .simple(attribute: LDAPAttributeDescription(string: "uid")!, filtertype: .equal, value: Data("test1".utf8)), attributesToFetch: ["uid", "sn"]))
		try runOperationSync(op1)
		let objects1 = try op1.resultOrThrow().results
		XCTAssertEqual(objects1.count, 1)
		XCTAssertEqual(objects1[0].parsedDistinguishedName, LDAPDistinguishedName(uid: "test1", baseDN: baseDN))
		XCTAssertEqual(objects1[0].attributes["sn"], [Data("1".utf8)])
		XCTAssertNil(objects1[0].attributes["cn"])
		
		let op2 = SearchLDAPOperation(ldapConnector: connector, request: LDAPSearchRequest(scope: .children, base: baseDN, searchQuery: nil, attributesToFetch: ["uid", "sn"]))
		try runOperationSync(op2)
		let objects2 = try op2.resultOrThrow().results
		XCTAssertEqual(objects2.count, 3)
	}
	
	private func getConnectedLDAPConnector() throws -> LDAPConnector {
		let expectationObject = ErrorContainer()
		let expectation = XCTKVOExpectation(keyPath: #keyPath(ErrorContainer.error), object: expectationObject)
		
		/* We use the semi-singleton init, but purposefully not init via a
		 * semi-singleton store. */
		let connector = try LDAPConnector(key: ldapSettings)
		connector.connect(scope: (), handler: { error in
			expectationObject.error = error
		})
		XCTWaiter().wait(for: [expectation], timeout: 3)
		
		if let e = expectationObject.error {throw e}
		assert(connector.isConnected)
		return connector
	}
	
	private func runOperationSync(_ operation: Operation) throws {
		operation.start()
		
		let expectation = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation, expectedValue: true)
		guard XCTWaiter().wait(for: [expectation], timeout: 5) == .completed else {
			throw InternalError(message: "The operation did not run fast enough")
		}
	}
	
	@objc
	private class ErrorContainer : NSObject {
		@objc dynamic var error: Error?
	}
	
}
