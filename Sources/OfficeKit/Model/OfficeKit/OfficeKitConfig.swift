/*
 * OfficeKitConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation



public struct OfficeKitConfig {
	
	public struct LDAPConfig {
		
		public var connectorSettings: LDAPConnector.Settings
		public var baseDNPerDomain: [String: LDAPDistinguishedName]
		public var peopleBaseDNPerDomain: [String: LDAPDistinguishedName]?
		public var adminGroupsDN: [LDAPDistinguishedName]
		
		public var allBaseDNs: [LDAPDistinguishedName] {
			return Array(baseDNPerDomain.values)
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
	
	public struct GoogleConfig {
		
		public var connectorSettings: GoogleJWTConnector.Settings
		public var primaryDomains: [String]
		
		public init(connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: [String]) {
			connectorSettings = c
			primaryDomains = d
		}
		
	}
	
	public struct GitHubConfig {
		
		public var connectorSettings: GitHubJWTConnector.Settings
		
		public init(connectorSettings c: GitHubJWTConnector.Settings) {
			connectorSettings = c
		}
		
	}
	
	/* *************************
	   MARK: - Connector Configs
	   ************************* */
	
	/** Key is a domain alias, value is the actual domain */
	public var domainAliases: [String: String]
	
	public var ldapConfig: LDAPConfig?
	public func ldapConfigOrThrow() throws -> LDAPConfig {return try nil2throw(ldapConfig, "LDAP Config")}
	
	public var googleConfig: GoogleConfig?
	public func googleConfigOrThrow() throws -> GoogleConfig {return try nil2throw(googleConfig, "Google Config")}
	
	public var gitHubConfig: GitHubConfig?
	public func gitHubConfigOrThrow() throws -> GitHubConfig {return try nil2throw(gitHubConfig, "GitHub Config")}
	
	/* ************
      MARK: - Init
	   ************ */
	
	public init(domainAliases da: [String: String], ldapConfig ldap: LDAPConfig?, googleConfig google: GoogleConfig?, gitHubConfig gitHub: GitHubConfig?) {
		domainAliases = da
		ldapConfig = ldap
		googleConfig = google
		gitHubConfig = gitHub
	}
	
	public func mainDomain(for domain: String) -> String {
		if let d = domainAliases[domain] {return d}
		return domain
	}
	
}
