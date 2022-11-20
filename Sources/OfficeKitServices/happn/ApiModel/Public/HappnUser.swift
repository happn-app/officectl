/*
 * HappnUser.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import CommonOfficePropertiesFromHappn
import Email



public struct HappnUser : Sendable, Hashable, Codable {
	
	public enum UserType : String, Sendable, Codable {
		
		case client
		
	}
	
	public var type: UserType = .client
	
	public var login: Email
	public var id: String?
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var gender: Gender?
	public var birthDate: Date? {
		get {_birthDate}
		set {_birthDate = newValue}
	}
	
	public var password: String?
	
	public init(login l: Email) {
		login = l
		gender = .male /* Male users by default. I’m crazy like that. */
		_birthDate = Date(timeIntervalSinceNow: -21*366*24*60*60) /* ~21 yo by default */
	}
	
	internal enum CodingKeys : String, CodingKey {
		case type
		case login, id
		case firstName = "first_name", lastName = "last_name", nickname
		case gender, _birthDate = "birth_date"
		case password
	}
	
	@HappnBirthDateWrapper
	internal var _birthDate: Date?
	
}
