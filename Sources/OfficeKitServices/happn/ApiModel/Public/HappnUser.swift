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
	
	public enum Status : String, Sendable, Codable {
		
		case active = "ACTIVE"
		case signUpValidation = "SIGN_UP_VALIDATION"
		
		case deactivated = "DEACTIVATED"
		case banned = "BANNED"
		
	}
	
	/* Updating the login is not possible, so this is a `let`, not a `var`. */
	public let login: Email
	public var id: String?
	
	public var type: UserType = .client
	public var status: Status?
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var gender: Gender?
	public var birthDate: Date? {
		get {_birthDate}
		set {_birthDate = newValue}
	}
	
	public var password: String?
	
	/* The gender and birth date are mandatory to create a new user, and usually not set, so we define a non-nil default value. */
	public init(login: Email, gender: Gender? = .male, birthDate: Date? = Date(timeIntervalSinceNow: -21*366*24*60*60)/* ~21 yo */) {
		self.login = login
		self.gender = gender
		self._birthDate = birthDate
	}
	
	internal func forPatching(properties: Set<CodingKeys>) -> HappnUser {
		var ret = HappnUser(login: login, gender: nil, birthDate: nil)
		for property in properties {
			switch property {
				case .login, .id, .type: (/*nop*/)
				case .status:     ret.status    = status
				case .firstName:  ret.firstName = firstName
				case .lastName:   ret.lastName  = lastName
				case .nickname:   ret.nickname  = nickname
				case .gender:     ret.gender    = gender
				case ._birthDate: ret.birthDate = birthDate
				case .password:   ret.password  = password
			}
		}
		return ret
	}
	
	internal enum CodingKeys : String, CodingKey {
		case login, id
		case type, status
		case firstName = "first_name", lastName = "last_name", nickname
		case gender, _birthDate = "birth_date"
		case password
	}
	
	@HappnBirthDateWrapper
	internal var _birthDate: Date?
	
}
