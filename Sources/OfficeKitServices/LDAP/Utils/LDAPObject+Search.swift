/*
 * LDAPObject+Search.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/07.
 */

import Foundation

import COpenLDAP

import OfficeKit2



internal extension LDAPObject {
	
	static func search(_ request: LDAPSearchRequest, connector: LDAPConnector) async throws -> (results: [LDAPObject], references: [[String]]) {
		return try await connector.performLDAPCommunication{ ldapPtr in
			/* We use ldap_search_ext_s (the synchronous version of the function).
			 * The operation should be run on a queue to have async behavior.
			 * We won't use the async version of the function because it does not have a handler;
			 *  instead one have to poll the results using the ldap_result method, which is not convenient nor useful for our use-case
			 *  compared to the synchronous alternative.
			 * As a downside, we cannot cancel the search operation quickly (the search from the libldap has to finish first).
			 * For our use case it should be fine (actually correct cancellation has not even been implemented later).
			 * Another (guessed) downside is if we have multiple requests launched on the same connection, they won’t be run at the same time,
			 *  one long request potentially blocking another small request. */
			var searchResultMessagePtr: OpaquePointer? /* “LDAPMessage*”; Cannot use the LDAPMessage type (not exported to Swift, because opaque in C headers...) */
			let searchResultError = CBridge.withCLDAPArrayOfString(array: request.attributesToFetch.flatMap{ Array($0) }){ attributesPtr in
				return ldap_search_ext_s(
					ldapPtr,
					request.base.stringValue, request.scope.rawValue, request.searchQuery?.stringValue, attributesPtr,
					0/* We want attributes and values */, nil/* Server controls */, nil/* Client controls */,
					nil/* Timeout */, 0/* Size limit */, &searchResultMessagePtr
				)
			}
			defer {_ = ldap_msgfree(searchResultMessagePtr)}
			
			guard searchResultError != LDAP_NO_SUCH_OBJECT else {
				/* Indicates the target object cannot be found.
				 * This code is not returned on following operations:
				 *   - Search operations that find the search base but cannot find any entries that match the search filter.
				 *   - Bind operations. */
				return (results: [], references: [])
			}
			guard searchResultError == LDAP_SUCCESS else {
				Conf.logger?.info("Cannot search LDAP: \(String(cString: ldap_err2string(searchResultError)))")
				throw OpenLDAPError(code: searchResultError)
			}
			
			var swiftResults = [LDAPObject]()
			var swiftReferences = [[String]]()
			var nextMessage = ldap_first_entry(ldapPtr, searchResultMessagePtr)
			while let currentMessage = nextMessage {
				nextMessage = ldap_next_message(ldapPtr, currentMessage)
				
				switch ber_tag_t(ldap_msgtype(currentMessage)) {
					case LDAP_RES_SEARCH_ENTRY: /* A search result. */
						/* Get DN for current search result entry. */
						guard let dnCString = ldap_get_dn(ldapPtr, currentMessage) else {
							Conf.logger?.info("Cannot get DN for search entry.")
							continue
						}
						defer {ldap_memfree(dnCString)}
						let dnString = String(cString: dnCString)
						guard let dn = try? LDAPDistinguishedName(string: dnString) else {
							throw Err.malformedDNReturnedByOpenLDAP(dnString)
						}
						
						/* Get the other attributes for the current search result entry. */
						var ber: OpaquePointer?
						var swiftAttributesAndValues = LDAPRecord()
						var nextAttribute = ldap_first_attribute(ldapPtr, currentMessage, &ber)
						defer {ber_free(ber, 0)}
						while let currentAttribute = nextAttribute {
							defer {ldap_memfree(currentAttribute)}
							nextAttribute = ldap_next_attribute(ldapPtr, currentMessage, ber)
							
							/* Get the current attribute as an OID. */
							let currentAttributeString = String(cString: currentAttribute)
							guard let currentAttributeOID = LDAPObjectID(rawValue: currentAttributeString) else {
								throw Err.malformedAttributeReturnedByOpenLDAP(currentAttributeString)
							}
							
							/* Get the values for the attribute. */
							guard let valueSetPtr = ldap_get_values_len(ldapPtr, currentMessage, currentAttribute) else {
								/* To retrieve the error message: “ldap_err2string(ldapPtr.pointee.ld_errno)”.
								 * Does not work for Swift because ldapPtr is an Opaque Pointer (because it is opaque in the OpenLDAP headers). */
								Conf.logger?.info("Cannot get value set for attribute \(currentAttributeString)")
								continue
							}
							var swiftValues = [Data]()
							var currentValuePtr = valueSetPtr
							while let currentValue = currentValuePtr.pointee {
								defer {currentValuePtr = currentValuePtr.successor()}
								swiftValues.append(Data(bytes: currentValue.pointee.bv_val, count: Int(currentValue.pointee.bv_len)))
							}
							ldap_value_free_len(valueSetPtr)
							
							swiftAttributesAndValues[currentAttributeOID] = swiftValues
						}
						swiftResults.append(LDAPObject(forAnyObjectTypeWith: dn, record: swiftAttributesAndValues))
						
					case LDAP_RES_SEARCH_REFERENCE: /* UNTESTED (our server does not return search references; not sure what search references are anyway…) */
						var referrals: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?
						let err = ldap_parse_reference(ldapPtr, currentMessage, &referrals, nil/* Server Controls */, 0/* Do not free the message */)
						guard err == LDAP_SUCCESS else {
							Conf.logger?.info("Cannot get search reference: \(String(cString: ldap_err2string(err)))")
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
						Conf.logger?.info("Got unknown message of type \(ldap_msgtype(currentMessage)). Ignoring.")
				}
			}
			return (results: swiftResults, references: swiftReferences)
		}
	}
	
}
