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
	
	/** First name */
	public var givenName: String?
	/** Last name */
	public var surname: String?
	
	public var userPrincipalName: Email
	public var mail: Email?
	
	public var displayName: String?
	
	public var mobilePhone: String?
	public var businessPhones: [String] = []
	
	public enum CodingKeys : String, CodingKey {
		case id
		case givenName, surname
		case userPrincipalName, mail
		case displayName
		case mobilePhone, businessPhones
	}
	
}
