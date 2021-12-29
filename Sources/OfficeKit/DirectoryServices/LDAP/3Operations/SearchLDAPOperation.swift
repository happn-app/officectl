/*
 * SearchLDAPOperation.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/29.
 */

import Foundation

import HasResult
import RetryingOperation

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/3ec5155c2a3efa7aa64b66353024ed36ae77349b/Sources/PerfectLDAP/PerfectLDAP.swift */

public final class SearchLDAPOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = (results: [LDAPObject], references: [[String]])
	
	public let ldapConnector: LDAPConnector
	public let request: LDAPSearchRequest
	
	public private(set) var results = Result<ResultType, Error>.failure(OperationIsNotFinishedError())
	public var result: Result<ResultType, Error> {return results}
	
	public init(ldapConnector c: LDAPConnector, request r: LDAPSearchRequest) {
		ldapConnector = c
		request = r
	}
	
	public override func startBaseOperation(isRetry: Bool) {
//		assert(ldapConnector.isConnected)
		
		Task{
			results = await Result{
				/* We use ldap_search_ext_s (the synchronous version of the function).
				 * The operation should be run on a queue to have async behavior.
				 * We won't use the async version of the function because it does not have a handler;
				 * instead one have to poll the results using the ldap_result method, which
				 * is not convenient nor useful for our use-case compared to the synchronous alternative.
				 * As a downside, we cannot cancel the search operation quickly (the search from the libldap has to finish first).
				 * For our use case it should be fine (actually correct cancellation has not even been implemented later).
				 * Another (guessed) downside is if we have multiple requests launched on the same connection, they won’t be run at the same time,
				 * one long request potentially blocking another small request. */
				try await ldapConnector.performLDAPCommunication{ ldapPtr in
					var searchResultMessagePtr: OpaquePointer? /* “LDAPMessage*”; Cannot use the LDAPMessage type (not exported to Swift, because opaque in C headers...) */
					let searchResultError = withCLDAPArrayOfString(array: request.attributesToFetch.flatMap{ Array($0) }){ attributesPtr in
						return ldap_search_ext_s(
							ldapPtr,
							request.base.stringValue, request.scope.rawValue, request.searchQuery?.stringValue, attributesPtr,
							0 /* We want attributes and values */, nil /* Server controls */, nil /* Client controls */,
							nil /* Timeout */, 0 /* Size limit */, &searchResultMessagePtr
						)
					}
					defer {_ = ldap_msgfree(searchResultMessagePtr)}
					
					guard searchResultError == LDAP_SUCCESS else {
						OfficeKitConfig.logger?.info("Cannot search LDAP: \(String(cString: ldap_err2string(searchResultError)))")
						throw NSError(domain: "com.happn.officectl.openldap", code: Int(searchResultError), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(searchResultError))])
					}
					
					var swiftResults = [LDAPObject]()
					var swiftReferences = [[String]]()
					var nextMessage = ldap_first_entry(ldapPtr, searchResultMessagePtr)
					while let currentMessage = nextMessage {
						nextMessage = ldap_next_message(ldapPtr, currentMessage)
						
						switch ber_tag_t(ldap_msgtype(currentMessage)) {
							case LDAP_RES_SEARCH_ENTRY: /* A search result */
								guard let dnCString = ldap_get_dn(ldapPtr, currentMessage) else {
									OfficeKitConfig.logger?.info("Cannot get DN for search entry")
									continue
								}
								defer {ldap_memfree(dnCString)}
								
								var ber: OpaquePointer?
								var swiftAttributesAndValues = [String: [Data]]()
								var nextAttribute = ldap_first_attribute(ldapPtr, currentMessage, &ber)
								defer {ber_free(ber, 0)}
								while let currentAttribute = nextAttribute {
									defer {ldap_memfree(currentAttribute)}
									nextAttribute = ldap_next_attribute(ldapPtr, currentMessage, ber)
									
									let currentAttributeString = String(cString: currentAttribute)
									guard let valueSetPtr = ldap_get_values_len(ldapPtr, currentMessage, currentAttribute) else {
										/* To retrieve the error message: ldap_err2string(ldapPtr.pointee.ld_errno)
										 * But does not work because ldapPtr is an Opaque Pointer (because it is opaque in the OpenLDAP headers...) */
										OfficeKitConfig.logger?.info("Cannot get value set for attribute \(currentAttributeString)")
										continue
									}
									var swiftValues = [Data]()
									var currentValuePtr = valueSetPtr
									while let currentValue = currentValuePtr.pointee {
										defer {currentValuePtr = currentValuePtr.successor()}
										swiftValues.append(Data(bytes: currentValue.pointee.bv_val, count: Int(currentValue.pointee.bv_len)))
									}
									ldap_value_free_len(valueSetPtr)
									swiftAttributesAndValues[currentAttributeString] = swiftValues
								}
								let dnString = String(cString: dnCString)
								guard let dn = try? LDAPDistinguishedName(string: dnString) else {
									throw InternalError(message: "Got malformed dn '\(dnString)' from LDAP. Aborting search.")
								}
								swiftResults.append(LDAPObject(distinguishedName: dn, attributes: swiftAttributesAndValues))
								
							case LDAP_RES_SEARCH_REFERENCE: /* UNTESTED (our server does not return search references; not sure what search references are anyway…) */
								var referrals: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?
								let err = ldap_parse_reference(ldapPtr, currentMessage, &referrals, nil /* Server Controls */, 0 /* Do not free the message */)
								guard err == LDAP_SUCCESS else {
									OfficeKitConfig.logger?.info("Cannot get search reference: got error \(String(cString: ldap_err2string(err)))")
									continue
								}
								
								var swiftValues = [String]()
								var nextReferralPtr = referrals
								while let currentReferral = nextReferralPtr?.pointee {
									defer {ldap_memfree(currentReferral)}
									nextReferralPtr = nextReferralPtr?.successor()
									
									swiftValues.append(String(cString: currentReferral))
								}
								ldap_memfree(referrals)
								
								swiftReferences.append(swiftValues)
								
							case LDAP_RES_SEARCH_RESULT: /* The metadata about the search results */
								()
								
							default:
								OfficeKitConfig.logger?.info("Got unknown message of type \(ldap_msgtype(currentMessage)). Ignoring.")
						}
					}
					return (results: swiftResults, references: swiftReferences)
				}
			}
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}


public struct LDAPSearchRequest {
	
	public enum Scope : ber_int_t {
		
		case base = 0
		case singleLevel = 1
		case subtree = 2
		case children = 3 /* OpenLDAP Extension */
		case `default` = -1 /* OpenLDAP Extension */
		
	}
	
	public var scope: Scope
	public var base: LDAPDistinguishedName
	public var searchQuery: LDAPSearchQuery?
	
	public var attributesToFetch: Set<String>?
	
	public init(scope s: Scope, base b: LDAPDistinguishedName, searchQuery sq: LDAPSearchQuery?, attributesToFetch atf: Set<String>?) {
		base = b
		scope = s
		searchQuery = sq
		attributesToFetch = atf
	}
	
}
