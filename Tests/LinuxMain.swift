import XCTest

@testable import OfficeKitTests

var tests: [XCTestCaseEntry] = [
	testCase([
	]),
	testCase([
		("testInvalidAttributeDescriptionInstantiation1", LDAPSearchQueryTests.testInvalidAttributeDescriptionInstantiation1),
		("testInvalidAttributeDescriptionInstantiation2", LDAPSearchQueryTests.testInvalidAttributeDescriptionInstantiation2),
		("testInvalidAttributeDescriptionInstantiation3", LDAPSearchQueryTests.testInvalidAttributeDescriptionInstantiation3),
		("testAttributeDescriptionInstantiation1", LDAPSearchQueryTests.testAttributeDescriptionInstantiation1),
		("testAttributeDescriptionInstantiation2", LDAPSearchQueryTests.testAttributeDescriptionInstantiation2),
		("testAttributeDescriptionInstantiation3", LDAPSearchQueryTests.testAttributeDescriptionInstantiation3),
	]),
]
XCTMain(tests)
