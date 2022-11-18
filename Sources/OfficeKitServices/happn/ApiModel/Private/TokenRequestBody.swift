/*
 * TokenRequestBody.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/17.
 */

import Foundation



internal struct TokenRequestBody : Sendable, Encodable {
	
	enum Grant : Sendable, Encodable {
		
		case password(username: String, password: String)
		case refreshToken(String)
		
	}
	
	var clientID: String
	var clientSecret: String?
	
	var grant: Grant
	var scope: Set<String>
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		try container.encode(scope, forKey: .scope)
		try container.encode(clientID, forKey: .clientID)
		try container.encode(clientSecret, forKey: .clientSecret)
		switch grant {
			case let .password(username: username, password: password):
				try container.encode("password", forKey: .grantType)
				try container.encode(username, forKey: .username)
				try container.encode(password, forKey: .password)
				
			case let .refreshToken(token):
				try container.encode("refresh_token", forKey: .grantType)
				try container.encode(token, forKey: .refreshToken)
		}
	}
	
	private enum CodingKeys : String, CodingKey {
		case scope, clientID = "client_id", clientSecret = "client_secret"
		case grantType = "grant_type"
		case username, password
		case refreshToken = "refresh_token"
	}
	
}
