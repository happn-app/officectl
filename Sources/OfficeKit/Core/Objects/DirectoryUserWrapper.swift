/*
 * DirectoryUserWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation

import GenericJSON
import Logging



public struct DirectoryUserWrapper : DirectoryUser, Codable {
	
	public typealias UserIdType = TaggedId
	public typealias PersistentIdType = TaggedId
	
	public var userId: TaggedId
	public var persistentId: RemoteProperty<TaggedId> = .unsupported
	
	public var emails: RemoteProperty<[Email]> = .unsupported
	
	public var firstName: RemoteProperty<String?> = .unsupported
	public var lastName: RemoteProperty<String?> = .unsupported
	public var nickname: RemoteProperty<String?> = .unsupported
	
	/* Note: We could use GenericStorage, but this would complexify conformance
	 *       to Codable so we’ll keep JSON, at least for now. */
	public var underlyingUser: JSON?
	
	public init(email: Email) {
		self.init(userId: TaggedId(tag: "email", id: email.stringValue))
	}
	
	public init(userId uid: TaggedId, persistentId pId: TaggedId? = nil, underlyingUser u: JSON? = nil) {
		if TaggedId(string: uid.rawValue) != uid {
			OfficeKitConfig.logger?.error("Initing a DirectoryUserWrapper with a TaggedId whose string representation does not converts back to itself: \(uid)")
		}
		userId = uid
		persistentId = pId.map{ .set($0) } ?? .unsupported
		underlyingUser = u
	}
	
	public init(json: JSON) throws {
		underlyingUser = json[CodingKeys.underlyingUser.rawValue]
		
		userId = try TaggedId(string: json.string(forKey: CodingKeys.userId.rawValue))
		persistentId = try json.optionalString(forKey: CodingKeys.persistentId.rawValue, errorOnMissingKey: false).flatMap{ .set(TaggedId(string: $0)) } ?? .unsupported
		
		emails = (try json.optionalArrayOfStrings(forKey: CodingKeys.emails.rawValue, errorOnMissingKey: false)?.map{ try nil2throw(Email(string: $0)) }).flatMap{ .set($0) } ?? .unsupported
		
		if (try? json.null(forKey: CodingKeys.firstName.rawValue)) != nil {
			firstName = .set(nil)
		} else {
			firstName = try json.optionalString(forKey: CodingKeys.firstName.rawValue, errorOnMissingKey: false).flatMap{ .set($0) } ?? .unsupported
		}
		if (try? json.null(forKey: CodingKeys.lastName.rawValue)) != nil {
			lastName = .set(nil)
		} else {
			lastName = try json.optionalString(forKey: CodingKeys.lastName.rawValue, errorOnMissingKey: false).flatMap{ .set($0) } ?? .unsupported
		}
		if (try? json.null(forKey: CodingKeys.nickname.rawValue)) != nil {
			nickname = .set(nil)
		} else {
			nickname = try json.optionalString(forKey: CodingKeys.nickname.rawValue, errorOnMissingKey: false).flatMap{ .set($0) } ?? .unsupported
		}
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		underlyingUser = try container.decodeIfPresent(JSON.self, forKey: .underlyingUser)
		
		userId = try container.decode(TaggedId.self, forKey: .userId)
		persistentId = try container.decodeIfPresent(RemoteProperty<TaggedId>.self, forKey: .persistentId) ?? .unsupported
		
		emails = try container.decodeIfPresent(RemoteProperty<[Email]>.self, forKey: .emails) ?? .unsupported
		
		firstName = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .firstName) ?? .unsupported
		lastName = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .lastName) ?? .unsupported
		nickname = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .nickname) ?? .unsupported
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(underlyingUser, forKey: .underlyingUser)
		
		try container.encode(userId, forKey: .userId)
		try container.encodeIfSet(persistentId, forKey: .persistentId)
		
		try container.encodeIfSet(emails, forKey: .emails)
		
		try container.encodeIfSet(firstName, forKey: .firstName)
		try container.encodeIfSet(lastName, forKey: .lastName)
		try container.encodeIfSet(nickname, forKey: .nickname)
	}
	
	public func json() -> JSON {
		var res: [String: JSON] = [
			CodingKeys.userId.rawValue: .string(userId.stringValue)
		]
		
		if let u = underlyingUser {res[CodingKeys.underlyingUser.rawValue] = u}
		
		/* userId added above. */
		if let pId = persistentId.value {res[CodingKeys.persistentId.rawValue] = .string(pId.stringValue)}
		
		if let e = emails.value {res[CodingKeys.emails.rawValue] = .array(e.map{ .string($0.stringValue) })}
		
		if let fn = firstName.value {res[CodingKeys.firstName.rawValue] = fn.flatMap{ .string($0) } ?? .null}
		if let ln = lastName.value  {res[CodingKeys.lastName.rawValue]  = ln.flatMap{ .string($0) } ?? .null}
		if let nn = nickname.value  {res[CodingKeys.nickname.rawValue]  = nn.flatMap{ .string($0) } ?? .null}
		
		return .object(res)
	}
	
	public mutating func copyStandardNonIdProperties<U : DirectoryUser>(fromUser user: U) {
		emails = user.emails
		
		firstName = user.firstName
		lastName = user.lastName
		nickname = user.nickname
	}
	
	public mutating func applyHints(_ hints: [DirectoryUserProperty: Any?], blacklistedKeys: Set<DirectoryUserProperty> = [.userId]) {
		for (k, v) in hints {
			guard !blacklistedKeys.contains(k) else {continue}
			switch (k, v) {
			case (.userId, let s as String):   userId = TaggedId(string: s)
			case (.userId, let t as TaggedId): userId = t
				
			case (.persistentId, nil):               persistentId = .unset
			case (.persistentId, let s as String):   persistentId = .set(TaggedId(string: s))
			case (.persistentId, let t as TaggedId): persistentId = .set(t)
				
			case (.emails, nil):               emails = .unset
			case (.emails, let e as [Email]):  emails = .set(e)
			case (.emails, let s as [String]):
				guard let e = try? s.map({ try nil2throw(Email(string: $0)) }) else {
					OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value has invalid email(s): \(String(describing: v))")
					continue
				}
				emails = .set(e)
					
			case (.firstName, nil):             firstName = .unset
			case (.firstName, let s as String): firstName = .set(s)
				
			case (.lastName, nil):             lastName = .unset
			case (.lastName, let s as String): lastName = .set(s)
				
			case (.nickname, nil):             nickname = .unset
			case (.nickname, let s as String): nickname = .set(s)
				
			default:
				OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value has not a compatible type: \(String(describing: v))")
			}
		}
	}
	
	public var isEmailUser: Bool {
		return userId.tag == "email"
	}
	
	/** Return the email value of the id if the id is an email (`isEmailUser` is
	`true`). Might return `nil` even if `isEmailUser` is `true` if the value of
	the id is an invalid email. */
	public var userIdEmail: Email? {
		guard isEmailUser else {return nil}
		return Email(string: userId.id)
	}
	
	public func mainEmail(domainMap: [String: String] = [:]) -> Email? {
		if let email = userIdEmail {
			return email
		}
		
		let mainDomainEmails = emails.map{ Set($0.map{ $0.primaryDomainVariant(aliasMap: domainMap) }) }.value
		if let mainDomainEmails = mainDomainEmails, let e = mainDomainEmails.onlyElement {
			return e
		}
		
		return nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum CodingKeys : String, CodingKey {
		case underlyingUser
		case userId, persistentId
		case emails
		case firstName, lastName, nickname
	}
	
}
