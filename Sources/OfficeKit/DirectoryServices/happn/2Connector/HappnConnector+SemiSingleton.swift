/*
 * HappnConnector+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/29.
 */

import Foundation

import SemiSingleton



extension HappnConnector : SemiSingleton {
	
	public struct Settings : Hashable {
		
		public let baseURL: URL
		
		public let clientId: String
		public let clientSecret: String
		
		public let authMode: AuthMode
		
		public init(baseURL url: URL, clientId id: String, clientSecret s: String, username u: String, password p: String) {
			baseURL = url
			clientId = id
			clientSecret = s
			authMode = .userPass(username: u, password: p)
		}
		
		public init(baseURL url: URL, clientId id: String, clientSecret s: String, refreshToken t: String) {
			baseURL = url
			clientId = id
			clientSecret = s
			authMode = .refreshToken(t)
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public convenience init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) {
		self.init(key: s)
	}
	
	public convenience init(key s: Settings) {
		self.init(baseURL: s.baseURL, clientId: s.clientId, clientSecret: s.clientSecret, authMode: s.authMode)
	}
	
}
