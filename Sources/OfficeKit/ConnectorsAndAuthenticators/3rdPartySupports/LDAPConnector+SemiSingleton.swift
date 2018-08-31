/*
 * LDAPConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 31/08/2018.
 */

import Foundation

import SemiSingleton



extension LDAPConnector : SemiSingletonWithFallibleInit {
	
	public struct Settings : Hashable {
		
		public var ldapURL: URL
		public var protocolVersion: LDAPProtocolVersion
		public var authMode: AuthMode
		
		public init(ldapURL u: URL, protocolVersion v: LDAPProtocolVersion) {
			ldapURL = u
			authMode = .none
			protocolVersion = v
		}
		
		public init(ldapURL u: URL, protocolVersion v: LDAPProtocolVersion, username: String, password: String) {
			ldapURL = u
			protocolVersion = v
			authMode = .userPass(username: username, password: password)
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	
	public convenience init(key s: Settings) throws {
		try self.init(ldapURL: s.ldapURL, protocolVersion: s.protocolVersion, authMode: s.authMode)
	}
	
}
