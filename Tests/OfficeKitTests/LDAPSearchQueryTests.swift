import XCTest
@testable import OfficeKit



class LDAPSearchQueryTests : XCTestCase {
	
	func testInvalidAttributeDescriptionInstantiation0() {
		let attributeDescription = LDAPAttributeDescription(stringOid: "1")
		XCTAssertNil(attributeDescription)
	}
	
	func testInvalidAttributeDescriptionInstantiation1() {
		let attributeDescription = LDAPAttributeDescription(stringOid: "1.5.4.00")
		XCTAssertNil(attributeDescription)
	}
	
	func testInvalidAttributeDescriptionInstantiation2() {
		let attributeDescription = LDAPAttributeDescription(stringOid: "0abcde")
		XCTAssertNil(attributeDescription)
	}
	
	func testInvalidAttributeDescriptionInstantiation3() {
		let attributeDescription = LDAPAttributeDescription(stringOid: "abcde*")
		XCTAssertNil(attributeDescription)
	}
	
	/* From https://tools.ietf.org/html/rfc4512#section-2.5 */
	func testAttributeDescriptionInstantiation1() {
		let attributeDescription = LDAPAttributeDescription(string: "2.5.4.0")
		let attributeDescriptionRef = LDAPAttributeDescription(stringOid: "2.5.4.0")
		XCTAssertEqual(attributeDescription, attributeDescriptionRef)
	}
	
	/* From https://tools.ietf.org/html/rfc4512#section-2.5 */
	func testAttributeDescriptionInstantiation2() {
		let attributeDescription = LDAPAttributeDescription(string: "cn;lang-de;lang-en")
		let attributeDescriptionRef = LDAPAttributeDescription(stringOid: "cn", options: ["lang-de", "lang-en"])
		XCTAssertEqual(attributeDescription, attributeDescriptionRef)
	}
	
	/* From https://tools.ietf.org/html/rfc4512#section-2.5 */
	func testAttributeDescriptionInstantiation3() {
		let attributeDescription = LDAPAttributeDescription(stringOid: "owner")
		let attributeDescriptionRef = LDAPAttributeDescription(string: "owner")
		XCTAssertEqual(attributeDescription, attributeDescriptionRef)
	}
	
}
