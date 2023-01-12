/*
 * HappnUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/28.
 */

import Foundation

import Email

import OfficeModel



public struct HappnUser : Hashable, Codable {
	
	public enum HappnType : String, Sendable, Codable {
		
		case client
		
	}
	
	public enum Gender : String, Sendable, Codable {
		
		case male
		case female
		
	}
	
	public var type: HappnType = .client
	
	public var login: String?
	@RemoteProperty
	public var id: String?
	
	@RemoteProperty
	public var firstName: String?
	@RemoteProperty
	public var lastName: String?
	@RemoteProperty
	public var nickname: String?
	
	@RemoteProperty
	public var gender: Gender?
	@RemoteProperty
	public var birthDate: Date?
	
	@RemoteProperty
	public var password: String?
	
	public init(login l: String?) {
		login = l
		gender = .male /* Male users by default. I’m crazy like that. */
		birthDate = Date(timeIntervalSinceNow: -21*366*24*60*60) /* ~21 yo by default */
	}
	
	public static func ==(_ user1: HappnUser, _ user2: HappnUser) -> Bool {
		return user1.login == user2.login
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(login)
	}
	
	public func cloneForPatching() -> HappnUser {
		var ret = HappnUser(login: login)
		ret.id = id
		return ret
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


extension HappnUser : DirectoryUser {
	
	public typealias IDType = String?
	public typealias PersistentIDType = String
	
	public var userID: String? {
		return login
	}
	public var remotePersistentID: RemoteProperty<String> {
		return _id
	}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return .set(login.flatMap{ Email(rawValue: $0) })
	}
	public var remoteOtherEmails: RemoteProperty<[Email]> {
		return .set([])
	}
	
	public var remoteFirstName: RemoteProperty<String?> {_firstName.map{ $0 as String? }}
	public var remoteLastName: RemoteProperty<String?> {_lastName.map{ $0 as String? }}
	public var remoteNickname: RemoteProperty<String?> {_nickname.map{ $0 as String? }}
	
}
