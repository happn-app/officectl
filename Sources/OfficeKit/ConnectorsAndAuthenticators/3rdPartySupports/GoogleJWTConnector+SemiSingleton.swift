/*
 * GoogleJWTConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation

import SemiSingleton



extension GoogleJWTConnector : SemiSingletonWithFallibleInit {
	
	public struct Settings : Hashable {
		
		public var jsonCredentialsURL: URL
		public var urserBehalf: String?
		
		public init(jsonCredentialsURL url: URL, userBehalf u: String?) {
			jsonCredentialsURL = url
			urserBehalf = u
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(key: s)
	}
	
	public convenience init(key s: Settings) throws {
		try self.init(jsonCredentialsURL: s.jsonCredentialsURL, userBehalf: s.urserBehalf)
	}
	
}
