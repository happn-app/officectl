/*
 * OpenDirectoryConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/05/21.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import SemiSingleton



extension OpenDirectoryConnector : SemiSingletonWithFallibleInit {
	
	public struct Settings : Sendable, Hashable {
		
		public let proxySettings: ProxySettings?
		
		public let nodeName: String
		public let nodeCredentials: CredentialsSettings?
		
		public init(proxySettings ps: ProxySettings? = nil, nodeName n: String, nodeCredentials creds: CredentialsSettings?) {
			proxySettings = ps
			nodeName = n
			nodeCredentials = creds
		}
		
		/* Yes, if ProxySettings and CredentialsSettings were structs, the == and hash functions would not be needed, I know… */
		public static func ==(lhs: OpenDirectoryConnector.Settings, rhs: OpenDirectoryConnector.Settings) -> Bool {
			return (
				lhs.proxySettings?.hostname == rhs.proxySettings?.hostname &&
				lhs.proxySettings?.username == rhs.proxySettings?.username &&
				lhs.proxySettings?.password == rhs.proxySettings?.password &&
				
				lhs.nodeName == rhs.nodeName &&
				
				lhs.nodeCredentials?.recordType == rhs.nodeCredentials?.recordType &&
				lhs.nodeCredentials?.username == rhs.nodeCredentials?.username &&
				lhs.nodeCredentials?.password == rhs.nodeCredentials?.password
			)
		}
		
		public func hash(into hasher: inout Hasher) {
			hasher.combine(proxySettings?.hostname)
			hasher.combine(proxySettings?.username)
			hasher.combine(proxySettings?.password)
			
			hasher.combine(nodeName)
			
			hasher.combine(nodeCredentials?.recordType)
			hasher.combine(nodeCredentials?.username)
			hasher.combine(nodeCredentials?.password)
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public init(key s: Settings) throws {
		try self.init(proxySettings: s.proxySettings, nodeName: s.nodeName, nodeCredentials: s.nodeCredentials)
	}
	
}

#endif
