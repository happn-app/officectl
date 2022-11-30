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
	
	public var oU_id: TaggedID
	public var oU_persistentID: TaggedID?
	
	public var oU_isSuspended: Bool?
	
	public var oU_firstName: String?
	public var oU_lastName: String?
	public var oU_nickname: String?
	
	public var oU_emails: [Email]?
	
	public var underlyingUser: JSON?
	public var savedHints = [UserProperty: String?]()
	
	public var sourceServiceID: String {
		return oU_id.tag
	}
	
	public init(id uid: TaggedID, persistentID pId: TaggedID? = nil, underlyingUser u: JSON? = nil, hints: [UserProperty: String?] = [:]) {
		oU_id = uid
		oU_persistentID = pId
		
		underlyingUser = u
		savedHints = hints
	}
	
	public init(hints: [UserProperty: String?]) {
		self.oU_id = TaggedID(tag: "", id: UUID().uuidString)
		applyAndSaveHints(hints, blacklistedKeys: [.id])
	}
	
	public init(copying other: UserWrapper) {
		oU_id = other.oU_id
		oU_persistentID = other.oU_persistentID
		
		oU_isSuspended = other.oU_isSuspended
		
		oU_firstName = other.oU_firstName
		oU_lastName = other.oU_lastName
		oU_nickname = other.oU_nickname
		
		oU_emails = other.oU_emails
		
		underlyingUser = other.underlyingUser
		savedHints = other.savedHints
	}
	
	public init(json: JSON, forcedUserID: TaggedID?) throws {
		oU_id = try forcedUserID ?? TaggedID(string: json[CodingKeys.oU_id.rawValue]?.stringValue ?! Err.invalidJSONEncodedUserWrapper)
		oU_persistentID = try json[CodingKeys.oU_persistentID.rawValue].flatMap{ try TaggedID(string: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) }
		
		oU_isSuspended = try json[CodingKeys.oU_isSuspended.rawValue].flatMap{ try $0.boolValue ?! Err.invalidJSONEncodedUserWrapper }
		
		oU_firstName = try json[CodingKeys.oU_firstName.rawValue].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		oU_lastName  = try json[CodingKeys.oU_lastName.rawValue ].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		oU_nickname  = try json[CodingKeys.oU_nickname.rawValue ].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		
		oU_emails = try json[CodingKeys.oU_emails.rawValue].flatMap{ try ($0.arrayValue ?! Err.invalidJSONEncodedUserWrapper).map{ try Email(rawValue: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) ?! Err.invalidJSONEncodedUserWrapper } }
		
		underlyingUser = json[CodingKeys.underlyingUser.rawValue]
		savedHints = json[CodingKeys.savedHints.rawValue]?.objectValue?.mapKeys{ UserProperty(rawValue: $0) }.compactMapValues{ $0.stringValue } ?? [:]
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Any? {
		return savedHints[.init(stringLiteral: property)].flatMap{ $0 }
	}
	
	public func json(includeSavedHints: Bool = false) -> JSON {
		var res = [String: JSON]()
		
		if let u = underlyingUser {res[CodingKeys.underlyingUser.rawValue] = u}
		if includeSavedHints {res[CodingKeys.savedHints.rawValue] = .object(savedHints.mapKeys{ $0.rawValue }.mapValues{ $0.flatMap{ .string($0) } ?? .null })}
		
		res[CodingKeys.oU_id.rawValue] = .string(oU_id.stringValue)
		if let pID = oU_persistentID {res[CodingKeys.oU_persistentID.rawValue] = .string(pID.stringValue)}
		
		if let s = oU_isSuspended {res[CodingKeys.oU_isSuspended.rawValue] = .bool(s)}
		
		if let fn = oU_firstName {res[CodingKeys.oU_firstName.rawValue] = .string(fn)}
		if let ln = oU_lastName  {res[CodingKeys.oU_lastName.rawValue]  = .string(ln)}
		if let nn = oU_nickname  {res[CodingKeys.oU_nickname.rawValue]  = .string(nn)}
		
		if let e = oU_emails {res[CodingKeys.oU_emails.rawValue] = .array(e.map{ .string($0.rawValue) })}
		
		return .object(res)
	}
	
	public mutating func copyStandardNonIDProperties<U : User>(fromUser user: U) {
		oU_isSuspended = user.oU_isSuspended
		
		oU_firstName = user.oU_firstName
		oU_lastName = user.oU_lastName
		oU_nickname = user.oU_nickname
		
		oU_emails = user.oU_emails
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
		if replaceAllPreviouslySavedHints {
			savedHints = [:]
		}
		
		var modifiedKeys = Set<UserProperty>()
		for (hintKey, hintValue) in hints {
			guard !blacklistedKeys.contains(hintKey) else {
				continue
			}
			
			savedHints[hintKey] = hintValue
			
			let touchedKey: Bool
			switch hintKey {
				case .id:
					guard let hintValue else {
						Conf.logger?.error("Asked to remove the id of a wrapped user (nil value for id in hints). This is illegal, I’m not doing it.")
						continue
					}
					touchedKey = Self.setValueIfNeeded(TaggedID(string: hintValue), in: &oU_id)
				case .persistentID:
					touchedKey = Self.setValueIfNeeded(hintValue.flatMap(TaggedID.init(string:)), in: &oU_persistentID)
					
				case .isSuspended:
					touchedKey = Self.setValueIfNeeded(hintValue, in: &oU_isSuspended, converter: { Bool($0) })
					
				case .firstName: touchedKey = Self.setValueIfNeeded(hintValue, in: &oU_firstName)
				case .lastName:  touchedKey = Self.setValueIfNeeded(hintValue, in: &oU_lastName)
				case .nickname:  touchedKey = Self.setValueIfNeeded(hintValue, in: &oU_nickname)
					
				case .emails:
					touchedKey = Self.setValueIfNeeded(hintValue, in: &oU_emails, converter: Self.convertEmailsHintToEmails)
					
				default:
					Conf.logger?.warning("Cannot apply hint for key \(hintKey): key is unknown: \(String(describing: hintValue))")
					touchedKey = false
			}
			
			if touchedKey {
				modifiedKeys.insert(hintKey)
			}
		}
		
		return modifiedKeys
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum CodingKeys : String, CodingKey {
		case underlyingUser
		case savedHints
		
		case oU_id = "id", oU_persistentID = "persistent_id"
		case oU_isSuspended = "is_suspended"
		case oU_firstName = "first_name", oU_lastName = "last_name", oU_nickname = "nickname"
		case oU_emails = "emails"
	}
	
	private static func convertEmailsHintToEmails(_ hint: String) -> [Email]? {
		/* We split the emails around the newline: AFAICT a newline is always invalid in an email adresse, whatever RFC you use to parse them.
		 * Usually emails are separated by a comma, but a comma _can_ be in a valid email and we’d have to properly parse stuff to extract the different email addresses. */
		let splitHint = hint.split(separator: "\n")
		
		struct Internal__InvalidEmailErrorMarker : Error {} /* Used as a marker if we encounter an invalid email. */
		return try? splitHint.map{ try Email(rawValue: String($0)) ?! Internal__InvalidEmailErrorMarker() }
	}
	
}
