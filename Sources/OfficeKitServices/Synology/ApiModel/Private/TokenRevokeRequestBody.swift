/*
 * TokenRevokeRequestBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct TokenRevokeRequestBody : Sendable, Encodable {
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode("SYNO.API.Auth", forKey: .api)
		try container.encode(6,               forKey: .version)
		try container.encode("logout",         forKey: .method)
	}
	
	private enum CodingKeys : String, CodingKey {
		case api
		case version
		case method
	}
	
}
