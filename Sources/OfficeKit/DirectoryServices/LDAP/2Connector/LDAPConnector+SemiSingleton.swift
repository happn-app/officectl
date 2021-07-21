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
		public var startTLS: Bool
		public var authMode: AuthMode
		
		public init(ldapURL u: URL, protocolVersion v: LDAPProtocolVersion, startTLS tls: Bool) {
			ldapURL = u
			authMode = .none
			protocolVersion = v
			startTLS = tls
		}
		
		public init(ldapURL u: URL, protocolVersion v: LDAPProtocolVersion, startTLS tls: Bool, username: String, password: String) {
			ldapURL = u
			protocolVersion = v
			startTLS = tls
			authMode = .userPass(username: username, password: password)
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public convenience init(key s: Settings) throws {
		try self.init(ldapURL: s.ldapURL, protocolVersion: s.protocolVersion, startTLS: s.startTLS, authMode: s.authMode)
	}
	
}
