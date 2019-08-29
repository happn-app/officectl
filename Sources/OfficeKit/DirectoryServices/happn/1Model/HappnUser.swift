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
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		type = try container.decode(HappnType.self, forKey: .type)
		
		login = try container.decode(String?.self, forKey: .login)
		id = try container.decodeIfPresent(RemoteProperty<String>.self, forKey: .id) ?? .unset
		
		firstName = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .first_name) ?? .unset
		lastName  = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .last_name)  ?? .unset
		nickname  = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .nickname)   ?? .unset
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(type, forKey: .type)
		
		try container.encode(login, forKey: .login)
		try container.encodeIfSet(id, forKey: .id)
		
		try container.encodeIfSet(firstName, forKey: .first_name)
		try container.encodeIfSet(lastName,  forKey: .last_name)
		try container.encodeIfSet(nickname,  forKey: .nickname)
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
	
	public init(login l: String?, hints: [DirectoryUserProperty: Any] = [:]) {
		login = l
		
		firstName = (hints[.firstName] as? String).flatMap{ .set($0) } ?? .unset
		lastName  = (hints[.lastName]  as? String).flatMap{ .set($0) } ?? .unset
		nickname  = (hints[.nickname]  as? String).flatMap{ .set($0) } ?? .unset
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
	}
	
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
