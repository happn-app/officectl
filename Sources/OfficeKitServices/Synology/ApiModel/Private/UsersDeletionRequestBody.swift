/*
 * UsersDeletionRequestBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/07.
 */

import Foundation

import UnwrapOrThrow



struct UsersDeletionRequestBody : Sendable, Encodable {
	
	var users: [SynologyUser]
	
	func encode(to encoder: Encoder) throws {
		let userNames = try String(data: JSONEncoder().encode(users.map(\.name)), encoding: .utf8) ?! Err.internalError
		
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode("SYNO.Core.User",          forKey: .api)
		try container.encode(1,                         forKey: .version)
		try container.encode("delete",                  forKey: .method)
		try container.encode(userNames,                 forKey: .userNames)
	}
	
	private enum CodingKeys : String, CodingKey {
		case api
		case version
		case method
		
		case userNames = "name"
	}
	
}
