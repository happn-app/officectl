/*
 * OpenDirectoryConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import SemiSingleton



extension OpenDirectoryConnector : SemiSingletonWithFallibleInit {
	
	public struct Settings : Hashable {
		
		public let serverHostname: String
		public let username: String
		public let password: String
		public let nodeType: ODNodeType
		
		public init(serverHostname h: String, username u: String, password p: String, nodeType t: ODNodeType) {
			serverHostname = h
			username = u
			password = p
			nodeType = t
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public convenience init(key s: Settings) throws {
		try self.init(serverHostname: s.serverHostname, username: s.username, password: s.password, nodeType: s.nodeType)
	}
	
}


extension OpenDirectoryRecordAuthenticator : SemiSingletonWithFallibleInit {
	
	public struct Settings : Hashable {
		
		public let username: String
		public let password: String
		
		public init(username u: String, password p: String) {
			username = u
			password = p
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public convenience init(key s: Settings) throws {
		try self.init(username: s.username, password: s.password)
	}
	
}

#endif
