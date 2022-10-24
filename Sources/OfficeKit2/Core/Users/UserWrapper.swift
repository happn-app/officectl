/*
 * UserWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/09.
 */

import Foundation

import Email
@preconcurrency import GenericJSON
import Logging
import UnwrapOrThrow

import OfficeModelCore



public struct UserWrapper : User, Codable {
	
	public typealias IDType = TaggedID
	public typealias PersistentIDType = TaggedID
	
	public var id: TaggedID
	public var persistentID: TaggedID?
	
	public var identifyingEmails: [Email]?
	public var otherEmails: [Email]?
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var underlyingUser: JSON?
	
	/**
	 An attempt at something at some point.
	 Can probably be removed (set to private in the mean time). */
	private var savedHints = [UserProperty: String?]()
	
	public var sourceServiceID: String {
		return id.tag
	}
	
	public init(userID uid: TaggedID, persistentID pId: TaggedID? = nil, underlyingUser u: JSON? = nil, hints: [UserProperty: String?] = [:]) {
		if TaggedID(string: uid.rawValue) != uid {
			Conf.logger?.error("Initing a UserWrapper with a TaggedID whose string representation does not converts back to itself: \(uid)")
		}
		id = uid
		persistentID = pId
		
		underlyingUser = u
		savedHints = hints
	}
	
	public init(copying other: UserWrapper) {
		id = other.id
		persistentID = other.persistentID
		
		identifyingEmails = other.identifyingEmails
		otherEmails = other.otherEmails
		
		firstName = other.firstName
		lastName = other.lastName
		nickname = other.nickname
		
		underlyingUser = other.underlyingUser
	}
	
	public init(json: JSON, forcedUserID: TaggedID?) throws {
		underlyingUser = json[CodingKeys.underlyingUser.rawValue]
		savedHints = json[CodingKeys.savedHints.rawValue]?.objectValue?.mapKeys{ UserProperty(stringLiteral: $0) }.compactMapValues{ $0.stringValue } ?? [:]
		
		id = try forcedUserID ?? TaggedID(string: json[CodingKeys.id.rawValue]?.stringValue ?! Err.invalidJSONEncodedUserWrapper)
		persistentID = try json[CodingKeys.persistentID.rawValue].flatMap{ try TaggedID(string: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) }
		
		identifyingEmails = try json[CodingKeys.identifyingEmails.rawValue].flatMap{ try ($0.arrayValue ?! Err.invalidJSONEncodedUserWrapper).map{ try Email(rawValue: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) ?! Err.invalidJSONEncodedUserWrapper } }
		otherEmails       = try json[CodingKeys.otherEmails.rawValue      ].flatMap{ try ($0.arrayValue ?! Err.invalidJSONEncodedUserWrapper).map{ try Email(rawValue: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) ?! Err.invalidJSONEncodedUserWrapper } }
		
		firstName = try json[CodingKeys.firstName.rawValue].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		lastName  = try json[CodingKeys.lastName.rawValue ].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		nickname  = try json[CodingKeys.nickname.rawValue ].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
	}
	
	public func json(includeSavedHints: Bool = false) -> JSON {
		var res: [String: JSON] = [
			CodingKeys.id.rawValue: .string(id.stringValue)
		]
		
		if let u = underlyingUser {res[CodingKeys.underlyingUser.rawValue] = u}
		if includeSavedHints {res[CodingKeys.savedHints.rawValue] = .object(savedHints.mapKeys{ $0.rawValue }.mapValues{ $0.flatMap{ .string($0) } ?? .null })}
		
		/* id added above. */
		if let pID = persistentID {res[CodingKeys.persistentID.rawValue] = .string(pID.stringValue)}
		
		if let e = identifyingEmails {res[CodingKeys.identifyingEmails.rawValue] = .array(e.map{ .string($0.rawValue) })}
		if let e = otherEmails       {res[CodingKeys.otherEmails.rawValue]       = .array(e.map{ .string($0.rawValue) })}
		
		if let fn = firstName {res[CodingKeys.firstName.rawValue] = .string(fn)}
		if let ln = lastName  {res[CodingKeys.lastName.rawValue]  = .string(ln)}
		if let nn = nickname  {res[CodingKeys.nickname.rawValue]  = .string(nn)}
		
		return .object(res)
	}
	
	public mutating func copyStandardNonIDProperties<U : User>(fromUser user: U) {
		identifyingEmails = user.identifyingEmails
		otherEmails = user.otherEmails
		
		firstName = user.firstName
		lastName = user.lastName
		nickname = user.nickname
	}
	
	public func applyingAndSavingHints(_ hints: [UserProperty: String?], blacklistedKeys: Set<UserProperty> = [.id], replaceAllPreviouslySavedHints: Bool = false) -> UserWrapper {
		var ret = UserWrapper(copying: self)
		ret.applyAndSaveHints(hints, blacklistedKeys: blacklistedKeys, replaceAllPreviouslySavedHints: replaceAllPreviouslySavedHints)
		return ret
	}
	
	/**
	 Applies the hints it can, and trump all saved hints with the new ones.
	 If `replaceAllPreviouslySavedHints` is `true`, will also delete previously saved hints in the user.
	 Blacklisted keys are not saved.
	 
	 - Returns: The keys that have been modified. */
	@discardableResult
	public mutating func applyAndSaveHints(_ hints: [UserProperty: String?], blacklistedKeys: Set<UserProperty> = [.id], replaceAllPreviouslySavedHints: Bool = false) -> Set<UserProperty> {
		struct Internal__InvalidEmailErrorMarker : Error {} /* An error we only use internally. */
		
		if replaceAllPreviouslySavedHints {
			savedHints = [:]
		}
		
		var modifiedKeys = Set<UserProperty>()
		for (k, v) in hints {
			guard !blacklistedKeys.contains(k) else {continue}
			
			savedHints[k] = v
			
			var touchedKey = true
			switch k {
				case .id:           if let v = v {id = TaggedID(string: v)}
				case .persistentID: persistentID = v.flatMap{ TaggedID(string: $0) }
					
				case .identifyingEmails:
					/* We split the emails around the newline: AFAICT a newline is always invalid in an email adresse, whatever RFC you use to parse them.
					 * Usually emails are separated by a comma, but a comma _can_ be in a valid email and we’d have to properly parse stuff to extract the different email addresses. */
					let e = try? v.flatMap{ v -> [Email] in
						let l = v.split(separator: "\n")
						return try l.map{ try Email(rawValue: String($0)) ?! Internal__InvalidEmailErrorMarker() }
					}
					guard e != nil || v == nil else {
						Conf.logger?.warning("Cannot apply hint for key \(k): value has invalid email(s): \(String(describing: v))")
						continue
					}
					identifyingEmails = e
					
				case .otherEmails:
					let e = try? v.flatMap{ v -> [Email] in
						let l = v.split(separator: "\n")
						return try l.map{ try Email(rawValue: String($0)) ?! Internal__InvalidEmailErrorMarker() }
					}
					guard e != nil || v == nil else {
						Conf.logger?.warning("Cannot apply hint for key \(k): value has invalid email(s): \(String(describing: v))")
						continue
					}
					otherEmails = e
					
				case .firstName: firstName = v
				case .lastName:  lastName = v
				case .nickname:  nickname = v
					
				default:
					Conf.logger?.warning("Cannot apply hint for key \(k): value has not a compatible type or key is unknown: \(String(describing: v))")
					touchedKey = false
			}
			if touchedKey {modifiedKeys.insert(k)}
		}
		return modifiedKeys
	}
	
	public func mainEmail(domainMap: [String: String] = [:]) -> Email? {
		return identifyingEmails?.first?.primaryDomainVariant(aliasMap: domainMap)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum CodingKeys : String, CodingKey {
		case underlyingUser
		case savedHints
		
		case id, persistentID
		case identifyingEmails, otherEmails
		case firstName, lastName, nickname
	}
	
}
