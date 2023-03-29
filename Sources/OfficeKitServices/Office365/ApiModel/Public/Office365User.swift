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
	
	public enum CodingKeys : String, CodingKey {
		case id, accountEnabled
		case givenName, surname
		case userPrincipalName, mail, mailNickname
		case displayName
//		case mobilePhone, businessPhones
		case passwordProfile
	}
	
}
