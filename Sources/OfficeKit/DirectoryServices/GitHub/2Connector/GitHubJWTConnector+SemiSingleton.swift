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
		
		public var appId: String
		public var installationId: String
		public var privateKeyURL: URL
		
		public init(appId a: String, installationId i: String, privateKeyURL url: URL) {
			appId = a
			installationId = i
			privateKeyURL = url
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public convenience init(key s: Settings) throws {
		try self.init(appId: s.appId, installationId: s.installationId, privateKeyURL: s.privateKeyURL)
	}
	
}
