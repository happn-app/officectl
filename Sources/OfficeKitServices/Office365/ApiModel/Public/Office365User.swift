/*
 * Office365User.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/03.
 */

import Foundation

import Email



public struct Office365User : Sendable, Hashable, Codable {
	
	/* <https://learn.microsoft.com/en-us/graph/api/resources/passwordprofile> */
	public struct PasswordProfile : Sendable, Hashable, Codable {
		
		public var forceChangePasswordNextSignIn: Bool
		public var forceChangePasswordNextSignInWithMfa: Bool
		public var password: String
		
	}
	
	public var id: String?
	public var accountEnabled: Bool?
	
	/** First name */
	public var givenName: String?
	/** Last name */
	public var surname: String?
	
	public var userPrincipalName: Email
	public var mail: Email?
	public var mailNickname: String?
	
	public var displayName: String?
	
	/* These exist but we do not support them as we do not have created the custom properties to fetch them. */
//	public var mobilePhone: String?
//	public var businessPhones: [String]?
	
	public var passwordProfile: PasswordProfile?
	
	internal func forPatching(properties: Set<CodingKeys>) -> Office365User {
		var ret = Office365User(userPrincipalName: userPrincipalName)
		ret.id = id
		for property in properties {
			switch property {
				case .id, .userPrincipalName: (/*nop*/)
				case .accountEnabled:  ret.accountEnabled  = accountEnabled
				case .givenName:       ret.givenName       = givenName
				case .surname:         ret.surname         = surname
				case .mail:            ret.mail            = mail
				case .mailNickname:    ret.mailNickname    = mailNickname
				case .displayName:     ret.displayName     = displayName
				case .passwordProfile: ret.passwordProfile = passwordProfile
			}
		}
		return ret
	}
	
	public enum CodingKeys : String, CodingKey {
		case id, accountEnabled
		case givenName, surname
		case userPrincipalName, mail, mailNickname
		case displayName
//		case mobilePhone, businessPhones
		case passwordProfile
	}
	
}
