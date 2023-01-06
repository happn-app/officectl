/*
 * LDAPUser+OfficeModel.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import Email

import OfficeKit2



extension LDAPUser : User {
	
	public typealias UserIDType = LDAPDistinguishedName
	public typealias PersistentUserIDType = Never
	
	public init(oU_id userID: LDAPDistinguishedName) {
		id = userID
	}
	
	public var oU_id: LDAPDistinguishedName {
		return id
	}
	
	public var oU_persistentID: Never? {
		return nil
	}
	
	public var oU_isSuspended: Bool? {
		return nil
	}
	
	/* LDAPInetOrgPerson <https://www.ietf.org/rfc/rfc2798.txt> */
	public var oU_firstName: String? {
		return try? record[LDAPInetOrgPersonClass.GivenName.value(from: <#T##[Data]#>)]
	}
	
	public var oU_lastName: String? {
		<#code#>
	}
	
	public var oU_nickname: String? {
		<#code#>
	}
	
	public var oU_emails: [Email]? {
		<#code#>
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> (Sendable)? {
		<#code#>
	}
	
	public mutating func oU_setValue<V>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool where V : Sendable {
		<#code#>
	}
	
}
