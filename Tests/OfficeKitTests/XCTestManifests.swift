import XCTest

extension FutureTests {
    static let __allTests = [
        ("testWaitAll1", testWaitAll1),
    ]
}

extension LDAPOperationTests {
    static let __allTests = [
        ("test1_LDAPObjectCreation", test1_LDAPObjectCreation),
        ("test2_LDAPObjectRetrieval", test2_LDAPObjectRetrieval),
    ]
}

extension LDAPSearchQueryTests {
    static let __allTests = [
        ("testAttributeDescriptionInstantiation1", testAttributeDescriptionInstantiation1),
        ("testAttributeDescriptionInstantiation2", testAttributeDescriptionInstantiation2),
        ("testAttributeDescriptionInstantiation3", testAttributeDescriptionInstantiation3),
        ("testInvalidAttributeDescriptionInstantiation0", testInvalidAttributeDescriptionInstantiation0),
        ("testInvalidAttributeDescriptionInstantiation1", testInvalidAttributeDescriptionInstantiation1),
        ("testInvalidAttributeDescriptionInstantiation2", testInvalidAttributeDescriptionInstantiation2),
        ("testInvalidAttributeDescriptionInstantiation3", testInvalidAttributeDescriptionInstantiation3),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FutureTests.__allTests),
        testCase(LDAPOperationTests.__allTests),
        testCase(LDAPSearchQueryTests.__allTests),
    ]
}
#endif
