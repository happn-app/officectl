/*
 * LDAPBaseDNs.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/08/2019.
 */

import Foundation



public struct LDAPBaseDNs : Hashable {
	
	public var baseDNPerDomain: [String: LDAPDistinguishedName]
	public var peopleBaseDNPerDomain: [String: LDAPDistinguishedName]?
	
	public var allBaseDNs: Set<LDAPDistinguishedName> {
		return Set(baseDNPerDomain.values)
	}
	
	public var allDomains: Set<String> {
		return Set(baseDNPerDomain.keys)
	}
	
	public init(baseDNPerDomain bdn: [String: LDAPDistinguishedName], peopleDN: LDAPDistinguishedName?) {
		baseDNPerDomain = bdn
		peopleBaseDNPerDomain = peopleDN.flatMap{ peopleDN in bdn.mapValues{ peopleDN + $0 } }
	}
	
	public init(baseDNPerDomainString: [String: String], peopleDNString: String?) throws {
		let bdn = try baseDNPerDomainString.mapValues{ try LDAPDistinguishedName(string: $0) }
		
		let pdn = try peopleDNString.flatMap{ peopleDNString -> [String: LDAPDistinguishedName] in
			guard !peopleDNString.isEmpty else {return bdn}
			let pdnc = try LDAPDistinguishedName(string: peopleDNString)
			return bdn.mapValues{ pdnc + $0 }
		}
		
		baseDNPerDomain = bdn
		peopleBaseDNPerDomain = pdn
	}
	
	public func dn(fromEmail email: Email) -> LDAPDistinguishedName? {
		guard let peopleBaseDNPerDomain = peopleBaseDNPerDomain else {return nil}
		guard let baseDN = peopleBaseDNPerDomain[email.domain] else {return nil}
		return LDAPDistinguishedName(uid: email.username, baseDN: baseDN)
	}
	
}
