/*
 * Office365User.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/03.
 */

import Foundation

import Email



public struct Office365User : Sendable, Hashable, Codable {
	
	public var id: String?
	public var accountEnabled: Bool?
	
	/** First name */
	public var givenName: String?
	/** Last name */
	public var surname: String?
	
	public var userPrincipalName: Email
	public var mail: Email?
	
	public var displayName: String?
	
	/* These exist but we do not support them as we do not have created the custom properties to fetch them. */
//	public var mobilePhone: String?
//	public var businessPhones: [String]?
	
	public enum CodingKeys : String, CodingKey {
		case id, accountEnabled
		case givenName, surname
		case userPrincipalName, mail
		case displayName
//		case mobilePhone, businessPhones
	}
	
}
