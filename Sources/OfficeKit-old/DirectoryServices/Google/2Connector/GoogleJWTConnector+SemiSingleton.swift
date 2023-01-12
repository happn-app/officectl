/*
 * GoogleJWTConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/01/11.
 */

import Foundation

import SemiSingleton



extension GoogleJWTConnector : SemiSingletonWithFallibleInit {
	
	public struct Settings : Sendable, Hashable {
		
		public var jsonCredentialsURL: URL
		public var userBehalf: String?
		
		public init(jsonCredentialsURL url: URL, userBehalf u: String?) {
			jsonCredentialsURL = url
			userBehalf = u
		}
		
		public init(copying settings: Settings, newUserBehalf u: String?) {
			jsonCredentialsURL = settings.jsonCredentialsURL
			userBehalf = u
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public init(key s: Settings) throws {
		try self.init(jsonCredentialsURL: s.jsonCredentialsURL, userBehalf: s.userBehalf)
	}
	
}
