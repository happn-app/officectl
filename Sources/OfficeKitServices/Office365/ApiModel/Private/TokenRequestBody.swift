/*
 * TokenRequestBody.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation



struct TokenRequestBody : Sendable, Encodable {
	
	enum Grant {
		
		case clientSecret(String)
		case signedAssertion(String, type: String)
		
	}
	
	var grantType: String
	
	var clientID: String
	var grant: Grant
	
	var scope: String
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(scope, forKey: .scope)
		try container.encode(grantType, forKey: .grantType)
		try container.encode(clientID, forKey: .clientID)
		switch grant {
			case let .clientSecret(secret):
				try container.encode(secret, forKey: .clientSecret)
				
			case let .signedAssertion(assertion, type: type):
				try container.encode(type,      forKey: .clientAssertionType)
				try container.encode(assertion, forKey: .clientAssertion)
		}
	}
	
	private enum CodingKeys : String, CodingKey {
		case scope
		case clientID = "client_id"
		case clientSecret = "client_secret"
		case grantType = "grant_type"
		case clientAssertionType = "client_assertion_type"
		case clientAssertion = "client_assertion"
	}
	
}
