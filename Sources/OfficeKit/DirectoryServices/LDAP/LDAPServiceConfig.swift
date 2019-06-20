/*
 * LDAPServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct LDAPServiceConfig {
	
	public var connectorSettings: LDAPConnector.Settings
	public var baseDNPerDomain: [String: LDAPDistinguishedName]
	public var peopleBaseDNPerDomain: [String: LDAPDistinguishedName]?
	public var adminGroupsDN: [LDAPDistinguishedName]
	
	public var allBaseDNs: Set<LDAPDistinguishedName> {
		return Set(baseDNPerDomain.values)
	}
	
	public var allDomains: Set<String> {
		return Set(baseDNPerDomain.keys)
	}
	
	/**
	- parameter peopleDNString: The DN for the people, **relative to the base
	DN**. This is a different than the `peopleBaseDN` var in this struct, as
	the var contains the full people DN. */
	public init?(connectorSettings c: LDAPConnector.Settings, baseDNPerDomainString: [String: String], peopleDNString: String?, adminGroupsDNString: [String]) {
		guard let bdn = try? baseDNPerDomainString.mapValues({ try LDAPDistinguishedName(string: $0) }) else {return nil}
		
		let pdn: [String: LDAPDistinguishedName]?
		if let pdnString = peopleDNString {
			if pdnString.isEmpty {
				pdn = bdn
			} else {
				guard let pdnc = try? LDAPDistinguishedName(string: pdnString) else {return nil}
				pdn = bdn.mapValues{ pdnc + $0 }
			}
		} else {
			pdn = nil
		}
		
		guard let adn = try? adminGroupsDNString.map({ try LDAPDistinguishedName(string: $0) }) else {
			return nil
		}
		
		self.init(connectorSettings: c, baseDNPerDomain: bdn, peopleBaseDNPerDomain: pdn, adminGroupsDN: adn)
	}
	
	public init(connectorSettings c: LDAPConnector.Settings, baseDNPerDomain bdn: [String: LDAPDistinguishedName], peopleBaseDNPerDomain pbdn: [String: LDAPDistinguishedName]?, adminGroupsDN agdn: [LDAPDistinguishedName]) {
		connectorSettings = c
		baseDNPerDomain = bdn
		peopleBaseDNPerDomain = pbdn
		adminGroupsDN = agdn
	}
	
}
