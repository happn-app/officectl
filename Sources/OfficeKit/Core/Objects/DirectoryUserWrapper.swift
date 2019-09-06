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
	
	public var identifyingEmail: RemoteProperty<Email?> = .unsupported
	public var otherEmails: RemoteProperty<[Email]> = .unsupported
	
	public var firstName: RemoteProperty<String?> = .unsupported
	public var lastName: RemoteProperty<String?> = .unsupported
	public var nickname: RemoteProperty<String?> = .unsupported
	
	/* Note: We could use GenericStorage, but this would complexify conformance
	 *       to Codable so we’ll keep JSON, at least for now. */
	public var underlyingUser: JSON?
	
	/** An attempt at something at some point. Can probably be removed (set to
	private in the mean time). */
	private var savedHints = [DirectoryUserProperty: String?]()
	
	public init(userId uid: TaggedId, persistentId pId: TaggedId? = nil, underlyingUser u: JSON? = nil, hints: [DirectoryUserProperty: String?] = [:]) {
		if TaggedId(string: uid.rawValue) != uid {
			OfficeKitConfig.logger?.error("Initing a DirectoryUserWrapper with a TaggedId whose string representation does not converts back to itself: \(uid)")
		}
		userId = uid
		persistentId = pId.map{ .set($0) } ?? .unsupported
		
		underlyingUser = u
		savedHints = hints
	}
	
	public init(copying other: DirectoryUserWrapper) {
		userId = other.userId
		persistentId = other.persistentId
		
		identifyingEmail = other.identifyingEmail
		otherEmails = other.otherEmails
		
		firstName = other.firstName
		lastName = other.lastName
		nickname = other.nickname
		
		underlyingUser = other.underlyingUser
		
		savedHints = other.savedHints
	}
	
	public init(json: JSON, forcedUserId: TaggedId?) throws {
		underlyingUser = json[CodingKeys.underlyingUser.rawValue]
		savedHints = json[CodingKeys.savedHints.rawValue]?.objectValue?.mapKeys{ DirectoryUserProperty(stringLiteral: $0) }.compactMapValues{ $0.stringValue } ?? [:]
		
		userId = try forcedUserId ?? TaggedId(string: json.string(forKey: CodingKeys.userId.rawValue))
		persistentId = try json.optionalString(forKey: CodingKeys.persistentId.rawValue, errorOnMissingKey: false).flatMap{ .set(TaggedId(string: $0)) } ?? .unsupported
		
		identifyingEmail = try json.optionalString(forKey: CodingKeys.identifyingEmail.rawValue, errorOnMissingKey: false).flatMap{ try .set(nil2throw(Email(string: $0))) } ?? .unsupported
		otherEmails = (try json.optionalArrayOfStrings(forKey: CodingKeys.otherEmails.rawValue, errorOnMissingKey: false)?.map{ try nil2throw(Email(string: $0)) }).flatMap{ .set($0) } ?? .unsupported
		
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
		savedHints = try container.decodeIfPresent([DirectoryUserProperty: String?].self, forKey: .savedHints) ?? [:]
		
		userId = try container.decode(TaggedId.self, forKey: .userId)
		persistentId = try container.decodeIfPresent(RemoteProperty<TaggedId>.self, forKey: .persistentId) ?? .unsupported
		
		identifyingEmail = try container.decodeIfPresent(RemoteProperty<Email?>.self, forKey: .identifyingEmail) ?? .unsupported
		otherEmails = try container.decodeIfPresent(RemoteProperty<[Email]>.self, forKey: .otherEmails) ?? .unsupported
		
		firstName = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .firstName) ?? .unsupported
		lastName = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .lastName) ?? .unsupported
		nickname = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .nickname) ?? .unsupported
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(underlyingUser, forKey: .underlyingUser)
		try container.encode(savedHints, forKey: .savedHints)
		
		try container.encode(userId, forKey: .userId)
		try container.encodeIfSet(persistentId, forKey: .persistentId)
		
		try container.encodeIfSet(identifyingEmail, forKey: .identifyingEmail)
		try container.encodeIfSet(otherEmails, forKey: .otherEmails)
		
		try container.encodeIfSet(firstName, forKey: .firstName)
		try container.encodeIfSet(lastName, forKey: .lastName)
		try container.encodeIfSet(nickname, forKey: .nickname)
	}
	
	public func json(includeSavedHints: Bool = false) -> JSON {
		var res: [String: JSON] = [
			CodingKeys.userId.rawValue: .string(userId.stringValue)
		]
		
		if let u = underlyingUser {res[CodingKeys.underlyingUser.rawValue] = u}
		if includeSavedHints {res[CodingKeys.savedHints.rawValue] = .object(savedHints.mapKeys{ $0.rawValue }.mapValues{ $0.flatMap{ .string($0) } ?? .null })}
		
		/* userId added above. */
		if let pId = persistentId.value {res[CodingKeys.persistentId.rawValue] = .string(pId.stringValue)}
		
		if let e = identifyingEmail.value {res[CodingKeys.identifyingEmail.rawValue] = e.flatMap{ .string($0.stringValue) } ?? .null}
		if let e = otherEmails.value      {res[CodingKeys.otherEmails.rawValue]      = .array(e.map{ .string($0.stringValue) })}
		
		if let fn = firstName.value {res[CodingKeys.firstName.rawValue] = fn.flatMap{ .string($0) } ?? .null}
		if let ln = lastName.value  {res[CodingKeys.lastName.rawValue]  = ln.flatMap{ .string($0) } ?? .null}
		if let nn = nickname.value  {res[CodingKeys.nickname.rawValue]  = nn.flatMap{ .string($0) } ?? .null}
		
		return .object(res)
	}
	
	public mutating func copyStandardNonIdProperties<U : DirectoryUser>(fromUser user: U) {
		identifyingEmail = user.identifyingEmail
		otherEmails = user.otherEmails
		
		firstName = user.firstName
		lastName = user.lastName
		nickname = user.nickname
	}
	
	public func applyingAndSavingHints(_ hints: [DirectoryUserProperty: String?], blacklistedKeys: Set<DirectoryUserProperty> = [.userId], replaceAllPreviouslySavedHints: Bool = false) -> DirectoryUserWrapper {
		var ret = DirectoryUserWrapper(copying: self)
		ret.applyAndSaveHints(hints, blacklistedKeys: blacklistedKeys, replaceAllPreviouslySavedHints: replaceAllPreviouslySavedHints)
		return ret
	}
	
	/** Applies the hints it can, and trump all saved hints with the new ones. If
	`replaceAllPreviouslySavedHints` is `true`, will also delete previously saved
	hints in the user. Blacklisted keys are not saved. */
	public mutating func applyAndSaveHints(_ hints: [DirectoryUserProperty: String?], blacklistedKeys: Set<DirectoryUserProperty> = [.userId], replaceAllPreviouslySavedHints: Bool = false) {
		if replaceAllPreviouslySavedHints {
			savedHints = [:]
		}
		
		for (k, v) in hints {
			guard !blacklistedKeys.contains(k) else {continue}
			
			savedHints[k] = v
			
			switch (k, v) {
			case (.userId, let s?): userId = TaggedId(string: s)
				
			case (.persistentId, nil):      persistentId = .unset
			case (.persistentId, let s?):   persistentId = .set(TaggedId(string: s))
				
			case (.identifyingEmail, nil):             identifyingEmail = .unset
			case (.identifyingEmail, let s?):
				guard let e = Email(string: s) else {
					OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value is an invalid email: \(String(describing: v))")
					continue
				}
				identifyingEmail = .set(e)
				
			case (.otherEmails, nil):               otherEmails = .unset
			case (.otherEmails, let s?):
				/* Yes. We cannot represent an element in the list which contains a
				 * comma. Maybe one day we’ll do the generic thing… */
				let l = s.split(separator: ",")
				guard let e = try? l.map({ try nil2throw(Email(string: String($0))) }) else {
					OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value has invalid email(s): \(String(describing: v))")
					continue
				}
				otherEmails = .set(e)
				
			case (.firstName, nil):    firstName = .unset
			case (.firstName, let s?): firstName = .set(s)
				
			case (.lastName, nil):    lastName = .unset
			case (.lastName, let s?): lastName = .set(s)
				
			case (.nickname, nil):    nickname = .unset
			case (.nickname, let s?): nickname = .set(s)
				
			default:
				OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value has not a compatible type or key is unknown: \(String(describing: v))")
			}
		}
	}
	
	public func mainEmail(domainMap: [String: String] = [:]) -> Email? {
		return identifyingEmail.map{ $0?.primaryDomainVariant(aliasMap: domainMap) }.value ?? nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum CodingKeys : String, CodingKey {
		case underlyingUser
		case savedHints
		
		case userId, persistentId
		case identifyingEmail, otherEmails
		case firstName, lastName, nickname
	}
	
}
