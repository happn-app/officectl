/*
 * UsersListRequestBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import UnwrapOrThrow



struct UsersListRequestBody : Sendable, Encodable {
	
	var additionalFields: Set<SynologyUser.CodingKeys>?
	
	func encode(to encoder: Encoder) throws {
		let fieldsString = try additionalFields.flatMap{ additionalFields in
			try String(data: JSONEncoder().encode(additionalFields.map(\.rawValue)), encoding: .utf8) ?! Err.internalError
		}
		
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode("SYNO.Core.User", forKey: .api)
		try container.encode(1,                forKey: .version)
		try container.encode("list",           forKey: .method)
		try container.encode(fieldsString,     forKey: .additionalFields)
	}
	
	private enum CodingKeys : String, CodingKey {
		case api
		case version
		case method
		case additionalFields = "additional"
	}
	
}
