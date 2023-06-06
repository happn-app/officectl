/*
 * TokenRequestBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct TokenRequestBody : Sendable, Encodable {
	
	var username: String
	var password: String
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode("SYNO.API.Auth", forKey: .api)
		try container.encode(6,               forKey: .version)
		try container.encode("login",         forKey: .method)
		try container.encode(username,        forKey: .account)
		try container.encode(password,        forKey: .passwd)
		try container.encode("sid",           forKey: .format)
		/* We don’t need a CSRF token for requests from a GUI-less API. */
		try container.encode(false,           forKey: .enableCSRFToken)
	}
	
	private enum CodingKeys : String, CodingKey {
		case api
		case version
		case method
		case account
		case passwd
		case format
		case enableCSRFToken = "enable_syno_token"
	}
	
}
