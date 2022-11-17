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
	public var birthDate: Date?
	
	public var password: String?
	
	public init(login l: Email) {
		login = l
		gender = .male /* Male users by default. I’m crazy like that. */
		birthDate = Date(timeIntervalSinceNow: -21*366*24*60*60) /* ~21 yo by default */
	}
	
	internal static let birthDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		return dateFormatter
	}()
	
	private enum CodingKeys : String, CodingKey {
		case type
		case login, id
		case firstName = "first_name", lastName = "last_name", nickname
		case gender, birthDate = "birth_date"
		case password
	}
	
}
