/*
 * LDAPSearchOperation.swift
 * officectl
 *
 * Created by François Lamboley on 29/06/2018.
 */

import Foundation

import AsyncOperationResult
import RetryingOperation

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/3ec5155c2a3efa7aa64b66353024ed36ae77349b/Sources/PerfectLDAP/PerfectLDAP.swift */

@available(OSX, deprecated: 10.11) /* See LDAPConnector declaration. The core functionalities of this class will have to be rewritten for the OpenDirectory connector if we ever create it. */
public class LDAPSearchOperation : RetryingOperation {
	
	public let ldapConnector: LDAPConnector
	public let request: LDAPRequest
	
	public var results = AsyncOperationResult<(results: [LDAPObject], references: [[String]])>.error(OperationIsNotFinishedError())
	
	public init(ldapConnector c: LDAPConnector, request r: LDAPRequest) {
		ldapConnector = c
		request = r
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		/* We use ldap_search_ext_s (the synchronous version of the function). The
		 * operation should be run on a queue to have async behavior. We won't use
		 * the async version of the function because it does not have a handler;
		 * instead one have to poll the results using the ldap_result method,
		 * which is not convenient nor useful for our use-case compared to the
		 * synchronous alternative. */
		var searchResultMessagePtr: OpaquePointer? /* “LDAPMessage*”; Cannot use the LDAPMessage type (not exported to Swift, because opaque in C headers...) */
		let searchResultError = withCArrayOfString(array: request.attributesToFetch){ attributesPtr in
			return ldap_search_ext_s(
				ldapConnector.ldapPtr,
				request.base, request.scope.rawValue, request.searchFilter, attributesPtr,
				0 /* We want attributes and values */, nil /* Server controls */, nil /* Client controls */,
				nil /* Timeout */, 0 /* Size limit */, &searchResultMessagePtr
			)
		}
		defer {_ = ldap_msgfree(searchResultMessagePtr)}
		
		guard searchResultError == LDAP_SUCCESS else {
//			print("Cannot search LDAP: \(String(cString: ldap_err2string(searchResultError)))", to: &stderrStream)
			results = AORError(domain: "com.happn.officectl.openldap", code: Int(searchResultError), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(searchResultError))])
			return
		}
		
		var swiftResults = [LDAPObject]()
		var swiftReferences = [[String]]()
		var nextMessage = ldap_first_entry(ldapConnector.ldapPtr, searchResultMessagePtr)
		while let currentMessage = nextMessage {
			nextMessage = ldap_next_message(ldapConnector.ldapPtr, currentMessage)
			
			switch ber_tag_t(ldap_msgtype(currentMessage)) {
			case LDAP_RES_SEARCH_ENTRY: /* A search result */
				guard let dnCString = ldap_get_dn(ldapConnector.ldapPtr, currentMessage) else {
					print("Cannot get DN for a search entry", to: &stderrStream)
					continue
				}
				defer {ldap_memfree(dnCString)}
				
				var ber: OpaquePointer?
				var swiftAttributesAndValues = [String: [Data]]()
				var nextAttribute = ldap_first_attribute(ldapConnector.ldapPtr, currentMessage, &ber)
				defer {ber_free(ber, 0)}
				while let currentAttribute = nextAttribute {
					defer {ldap_memfree(currentAttribute)}
					nextAttribute = ldap_next_attribute(ldapConnector.ldapPtr, currentMessage, ber)
					
					let currentAttributeString = String(cString: currentAttribute)
					guard let valueSetPtr = ldap_get_values_len(ldapConnector.ldapPtr, currentMessage, currentAttribute) else {
						/* To retrieve the error message: ldap_err2string(ldapConnector.ldapPtr.pointee.ld_errno)
						 * But does not work because ldapPtr is an Opaque Pointer
						 * (because it is opaque in the OpenLDAP headers...) */
						print("Cannot get value set for attribute \(currentAttributeString)", to: &stderrStream)
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
				swiftResults.append(LDAPObject(distinguishedName: String(cString: dnCString), attributes: swiftAttributesAndValues))
				
			case LDAP_RES_SEARCH_REFERENCE: /* UNTESTED (our server does not return search references. A search reference (not sure what this is though...) */
				var referrals: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?
				let err = ldap_parse_reference(ldapConnector.ldapPtr, currentMessage, &referrals, nil /* Server Controls */, 0 /* Do not free the message */)
				guard err == LDAP_SUCCESS else {
					print("Cannot get search reference: got error \(String(cString: ldap_err2string(err)))", to: &stderrStream)
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
				print("Got unknown message of type \(ldap_msgtype(currentMessage)). Ignoring.", to: &stderrStream)
			}
			
			results = .success((results: swiftResults, references: swiftReferences))
		}
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	/* From https://github.com/PerfectlySoft/Perfect-LDAP/blob/3ec5155c2a3efa7aa64b66353024ed36ae77349b/Sources/PerfectLDAP/Utilities.swift */
	private func withCArrayOfString<R>(array: [String]?, _ body: (UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) throws -> R) rethrows -> R {
		guard let array = array else {
			return try body(nil)
		}
		
		/* Convert array to NULL-terminated array of pointers */
		var parr = (array as [String?] + [nil]).map{ $0.flatMap{ ber_strdup($0) } }
		defer {parr.forEach{ ber_memfree($0) }}
		
		return try parr.withUnsafeMutableBufferPointer{ try body($0.baseAddress) }
	}
	
}

public struct LDAPRequest {
	
	public enum Scope : ber_int_t {
		
		case base = 0
		case singleLevel = 1
		case subtree = 2
		case children = 3 /* OpenLDAP Extension */
		case `default` = -1 /* OpenLDAP Extension */
		
	}
	
	public var scope: Scope
	public var base: String
	public var searchFilter: String?
	
	public var attributesToFetch: [String]?
	
	public init(scope s: Scope, base b: String, searchFilter sf: String?, attributesToFetch atf: [String]?) {
		base = b
		scope = s
		searchFilter = sf
		attributesToFetch = atf
	}
	
}
