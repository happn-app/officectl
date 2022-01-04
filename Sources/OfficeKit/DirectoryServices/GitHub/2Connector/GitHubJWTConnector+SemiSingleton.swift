/*
 * GitHubJWTConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/01/11.
 */

import Foundation

import SemiSingleton



extension GitHubJWTConnector : SemiSingletonWithFallibleInit {
	
	public struct Settings : Hashable {
		
		public var appID: String
		public var installationID: String
		public var privateKeyURL: URL
		
		public init(appID a: String, installationID i: String, privateKeyURL url: URL) {
			appID = a
			installationID = i
			privateKeyURL = url
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public convenience init(key s: Settings) throws {
		try self.init(appID: s.appID, installationID: s.installationID, privateKeyURL: s.privateKeyURL)
	}
	
}
