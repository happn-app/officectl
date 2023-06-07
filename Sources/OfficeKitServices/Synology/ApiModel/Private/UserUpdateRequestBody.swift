/*
 * UserUpdateRequestBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/07.
 */

import Foundation

import UnwrapOrThrow



struct UserUpdateRequestBody : Sendable, Encodable {
	
	var user: SynologyUser
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode("SYNO.Core.User",          forKey: .api)
		try container.encode(1,                         forKey: .version)
		try container.encode("set",                     forKey: .method)
		try container.encode(user.name,                 forKey: .userName)
		try container.encode(user.description,          forKey: .userDescription)
		try container.encode(user.email,                forKey: .userEmail)
		try container.encode(user.expiration,           forKey: .userExpiration)
		try container.encode(user.password,             forKey: .userPassword)
		try container.encode(user.cannotChangePassword, forKey: .userCannotChangePassword)
		try container.encode(user.passwordNeverExpires, forKey: .userPasswordNeverExpires)
		try container.encode(user.passwordNeverExpires, forKey: .userPasswordNeverExpires)
	}
	
	private enum CodingKeys : String, CodingKey {
		case api
		case version
		case method
		
		case userName = "name"
		case userDescription = "description"
		case userEmail = "email"
		case userExpiration = "expired"
		case userPassword = "password"
		case userCannotChangePassword = "cannot_chg_passwd"
		case userPasswordNeverExpires = "passwd_never_expire"
	}
	
}
