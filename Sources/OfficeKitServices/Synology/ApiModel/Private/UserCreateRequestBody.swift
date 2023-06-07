/*
 * UserCreateRequestBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/07.
 */

import Foundation

import UnwrapOrThrow



struct UserCreateRequestBody : Sendable, Encodable {
	
	enum EmailNotificationMode : Sendable {
		case none
		case notifyUser(sendPassword: Bool)
	}
	
	var user: SynologyUser
	var emailNotificationMode: EmailNotificationMode = .none
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode("SYNO.Core.User",          forKey: .api)
		try container.encode(1,                         forKey: .version)
		try container.encode("create",                  forKey: .method)
		try container.encode(user.name,                 forKey: .userName)
		try container.encode(user.description,          forKey: .userDescription)
		try container.encode(user.email,                forKey: .userEmail)
		try container.encode(user.expiration,           forKey: .userExpiration)
		try container.encode(user.password,             forKey: .userPassword)
		try container.encode(user.cannotChangePassword, forKey: .userCannotChangePassword)
		try container.encode(user.passwordNeverExpires, forKey: .userPasswordNeverExpires)
		
		switch emailNotificationMode {
			case .none:
				try container.encode(false,        forKey: .notifyUserByEmail)
				try container.encode(false,        forKey: .sendUserPasswordInNotificationEmail)
				
			case .notifyUser(let sendPassword):
				try container.encode(true,         forKey: .notifyUserByEmail)
				try container.encode(sendPassword, forKey: .sendUserPasswordInNotificationEmail)
		}
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
		
		case notifyUserByEmail = "notify_by_email"
		case sendUserPasswordInNotificationEmail = "send_password"
	}
	
}
