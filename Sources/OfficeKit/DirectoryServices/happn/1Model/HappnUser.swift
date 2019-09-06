/*
 * HappnUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/08/2019.
 */

import Foundation



public struct HappnUser : Hashable, Codable {
	
	public enum HappnType : String, Codable {
		
		case client
		
	}
	
	public enum Gender : String, Codable {
		
		case male
		case female
		
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		type = try container.decode(HappnType.self, forKey: .type)
		
		login = try container.decode(String?.self, forKey: .login)
		id = try container.decodeIfPresent(RemoteProperty<String>.self, forKey: .id) ?? .unset
		
		firstName = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .first_name) ?? .unset
		lastName  = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .last_name)  ?? .unset
		nickname  = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .nickname)   ?? .unset
		
		gender = try container.decodeIfPresent(RemoteProperty<Gender>.self, forKey: .gender) ?? .unset
		
		let dateStr = try container.decodeIfPresent(RemoteProperty<String>.self, forKey: .birth_date) ?? .unset
		birthDate = try dateStr.map{
			guard let date = HappnUser.birthDateFormatter.date(from: $0) else {
				throw DecodingError.dataCorruptedError(forKey: .birth_date, in: container, debugDescription: "Cannot decode birth date")
			}
			return date
		}
		
		password = try container.decodeIfPresent(RemoteProperty<String>.self, forKey: .password) ?? .unset
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(type, forKey: .type)
		
		try container.encode(login, forKey: .login)
		try container.encodeIfSet(id, forKey: .id)
		
		try container.encodeIfSet(firstName, forKey: .first_name)
		try container.encodeIfSet(lastName,  forKey: .last_name)
		try container.encodeIfSet(nickname,  forKey: .nickname)
		
		try container.encodeIfSet(gender,                                                         forKey: .gender)
		try container.encodeIfSet(birthDate.map{ HappnUser.birthDateFormatter.string(from: $0) }, forKey: .birth_date)
		
		try container.encodeIfSet(password, forKey: .password)
	}
	
	public var type: HappnType = .client
	
	public var login: String?
	public var id: RemoteProperty<String> = .unset
	
	/* Technically I think the type is more RemoteProperty<String> but it does
	 * not change much, and avoids have “happnFirstName” and “firstName” (one
	 * representing the happn model, the other the DirectoryUser conformance). */
	public var firstName: RemoteProperty<String?> = .unset
	public var lastName: RemoteProperty<String?> = .unset
	public var nickname: RemoteProperty<String?> = .unset
	
	public var gender: RemoteProperty<Gender> = .unset
	public var birthDate: RemoteProperty<Date> = .unset
	
	public var password: RemoteProperty<String> = .unset
	
	public init(login l: String?, hints: [DirectoryUserProperty: Any] = [:]) {
		login = l
		
		firstName = (hints[.firstName] as? String).flatMap{ .set($0) } ?? .unset
		lastName  = (hints[.lastName]  as? String).flatMap{ .set($0) } ?? .unset
		nickname  = (hints[.nickname]  as? String).flatMap{ .set($0) } ?? .unset
		
		#warning("TODO")
		gender = (hints[.custom("gender")] as? Gender).flatMap{ .set($0) } ?? .set(.male)
		birthDate = (hints[.custom("birthdate")] as? Date).flatMap{ .set($0) } ?? .set(Date(timeIntervalSinceNow: -21*366*24*60*60))
		
		password = (hints[.password] as? String).flatMap{ .set($0) } ?? .set("toto")
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
	
	private enum CodingKeys : String, CodingKey {
		case type
		case login, id
		case first_name, last_name, nickname
		case gender, birth_date
		case password
	}
	
	private static let birthDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		return dateFormatter
	}()
	
}


extension HappnUser : DirectoryUser {
	
	public typealias UserIdType = String?
	public typealias PersistentIdType = String
	
	public var userId: String? {
		return login
	}
	public var persistentId: RemoteProperty<String> {
		return id
	}
	
	public var identifyingEmail: RemoteProperty<Email?> {
		return .set(login.flatMap{ Email(string: $0) })
	}
	public var otherEmails: RemoteProperty<[Email]> {
		return .set([])
	}
	
}
