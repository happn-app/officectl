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
		public var baseDN: LDAPDistinguishedName
		public var peopleBaseDN: LDAPDistinguishedName?
		public var adminGroupsDN: [LDAPDistinguishedName]
		
		/**
		- parameter peopleDNString: The DN for the people, **relative to the base
		DN**. This is a different than the `peopleBaseDN` var in this struct, as
		the var contains the full people DN. */
		public init?(connectorSettings c: LDAPConnector.Settings, baseDNString: String, peopleDNString: String?, adminGroupsDNString: [String]) {
			guard let bdn = try? LDAPDistinguishedName(string: baseDNString) else {return nil}
			
			let pdn: LDAPDistinguishedName?
			if let pdnString = peopleDNString {
				if pdnString.isEmpty {
					pdn = bdn
				} else {
					guard let pdnc = try? LDAPDistinguishedName(string: pdnString) else {return nil}
					pdn = pdnc + bdn
				}
			} else {
				pdn = nil
			}
			
			guard let adn = try? adminGroupsDNString.map({ try LDAPDistinguishedName(string: $0) }) else {
				return nil
			}
			
			self.init(connectorSettings: c, baseDN: bdn, peopleBaseDN: pdn, adminGroupsDN: adn)
		}
		
		public init(connectorSettings c: LDAPConnector.Settings, baseDN bdn: LDAPDistinguishedName, peopleBaseDN pbdn: LDAPDistinguishedName?, adminGroupsDN agdn: [LDAPDistinguishedName]) {
			connectorSettings = c
			baseDN = bdn
			peopleBaseDN = pbdn
			adminGroupsDN = agdn
		}
		
	}
	
	public struct GoogleConfig {
		
		public var connectorSettings: GoogleJWTConnector.Settings
		public var domains: [String]
		
		public init(connectorSettings c: GoogleJWTConnector.Settings, domains d: [String]) {
			connectorSettings = c
			domains = d
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
	
	public var ldapConfig: LDAPConfig?
	public func ldapConfigOrThrow() throws -> LDAPConfig {return try nil2throw(ldapConfig, "LDAP Config")}
	
	public var googleConfig: GoogleConfig?
	public func googleConfigOrThrow() throws -> GoogleConfig {return try nil2throw(googleConfig, "Google Config")}
	
	public var gitHubConfig: GitHubConfig?
	public func gitHubConfigOrThrow() throws -> GitHubConfig {return try nil2throw(gitHubConfig, "GitHub Config")}
	
	/* ************
      MARK: - Init
	   ************ */
	
	public init(ldapConfig ldap: LDAPConfig?, googleConfig google: GoogleConfig?, gitHubConfig gitHub: GitHubConfig?) {
		ldapConfig = ldap
		googleConfig = google
		gitHubConfig = gitHub
	}
	
}
