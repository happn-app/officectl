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
		
		public let clientID: String
		public let clientSecret: String
		
		public let authMode: AuthMode
		
		public init(baseURL url: URL, clientID id: String, clientSecret s: String, username u: String, password p: String) {
			baseURL = url
			clientID = id
			clientSecret = s
			authMode = .userPass(username: u, password: p)
		}
		
		public init(baseURL url: URL, clientID id: String, clientSecret s: String, refreshToken t: String) {
			baseURL = url
			clientID = id
			clientSecret = s
			authMode = .refreshToken(t)
		}
		
	}
	
	public typealias SemiSingletonKey = Settings
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public init(key s: Settings, additionalInfo: Void, store: SemiSingletonStore) {
		self.init(key: s)
	}
	
	public init(key s: Settings) {
		self.init(baseURL: s.baseURL, clientID: s.clientID, clientSecret: s.clientSecret, authMode: s.authMode)
	}
	
}
