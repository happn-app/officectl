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
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var emails: [Email]?
	
	public var password: String?
	
	public var underlyingUser: JSON?
	public var savedHints = [UserProperty: String?]()
	
	public var sourceServiceID: String {
		return id.tag
	}
	
	public init(id uid: TaggedID, persistentID pId: TaggedID? = nil, underlyingUser u: JSON? = nil, hints: [UserProperty: String?] = [:]) {
		id = uid
		persistentID = pId
		
		underlyingUser = u
		savedHints = hints
	}
	
	public init(hints: [UserProperty: String?]) {
		self.id = TaggedID(tag: "", id: UUID().uuidString)
		applyAndSaveHints(hints, blacklistedKeys: [.id])
	}
	
	public init(copying other: UserWrapper) {
		id = other.id
		persistentID = other.persistentID
		
		firstName = other.firstName
		lastName = other.lastName
		nickname = other.nickname
		
		emails = other.emails
		
		underlyingUser = other.underlyingUser
		savedHints = other.savedHints
	}
	
	public init(json: JSON, forcedUserID: TaggedID?) throws {
		id = try forcedUserID ?? TaggedID(string: json[CodingKeys.id.rawValue]?.stringValue ?! Err.invalidJSONEncodedUserWrapper)
		persistentID = try json[CodingKeys.persistentID.rawValue].flatMap{ try TaggedID(string: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) }
		
		firstName = try json[CodingKeys.firstName.rawValue].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		lastName  = try json[CodingKeys.lastName.rawValue ].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		nickname  = try json[CodingKeys.nickname.rawValue ].flatMap{ try $0.stringValue ?! Err.invalidJSONEncodedUserWrapper }
		
		emails = try json[CodingKeys.emails.rawValue].flatMap{ try ($0.arrayValue ?! Err.invalidJSONEncodedUserWrapper).map{ try Email(rawValue: $0.stringValue ?! Err.invalidJSONEncodedUserWrapper) ?! Err.invalidJSONEncodedUserWrapper } }
		
		underlyingUser = json[CodingKeys.underlyingUser.rawValue]
		savedHints = json[CodingKeys.savedHints.rawValue]?.objectValue?.mapKeys{ UserProperty(rawValue: $0) }.compactMapValues{ $0.stringValue } ?? [:]
	}
	
	public func valueForNonStandardProperty(_ property: String) -> Any? {
		return savedHints[.init(stringLiteral: property)].flatMap{ $0 }
	}
	
	public func json(includeSavedHints: Bool = false) -> JSON {
		var res = [String: JSON]()
		
		if let u = underlyingUser {res[CodingKeys.underlyingUser.rawValue] = u}
		if includeSavedHints {res[CodingKeys.savedHints.rawValue] = .object(savedHints.mapKeys{ $0.rawValue }.mapValues{ $0.flatMap{ .string($0) } ?? .null })}
		
		res[CodingKeys.id.rawValue] = .string(id.stringValue)
		if let pID = persistentID {res[CodingKeys.persistentID.rawValue] = .string(pID.stringValue)}
		
		if let fn = firstName {res[CodingKeys.firstName.rawValue] = .string(fn)}
		if let ln = lastName  {res[CodingKeys.lastName.rawValue]  = .string(ln)}
		if let nn = nickname  {res[CodingKeys.nickname.rawValue]  = .string(nn)}
		
		if let e = emails {res[CodingKeys.emails.rawValue] = .array(e.map{ .string($0.rawValue) })}
		
		return .object(res)
	}
	
	public mutating func copyStandardNonIDProperties<U : User>(fromUser user: U) {
		firstName = user.firstName
		lastName = user.lastName
		nickname = user.nickname
		
		emails = user.emails
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
					touchedKey = Self.setValueIfNeeded(TaggedID(string: hintValue), in: &id)
					
				case .firstName: touchedKey = Self.setValueIfNeeded(hintValue, in: &firstName)
				case .lastName:  touchedKey = Self.setValueIfNeeded(hintValue, in: &lastName)
				case .nickname:  touchedKey = Self.setValueIfNeeded(hintValue, in: &nickname)
					
				case .emails:
					guard let parsedHint = Self.convertEmailsHintToEmails(hintValue) else {
						Conf.logger?.warning("Cannot apply hint for key \(hintKey): value has invalid email(s): \(String(describing: hintValue))")
						continue
					}
					touchedKey = Self.setValueIfNeeded(parsedHint, in: &emails)
					
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
		
		case id, persistentID
		case firstName, lastName, nickname
		case emails
	}
	
	/**
	 Returns `.none` iif the conversion failed, `.some(.none)` iif the hint was `nil` and the emails if the conversion succeeds. */
	private static func convertEmailsHintToEmails(_ hint: String?) -> [Email]?? {
		guard let hint = hint else {
			return .some(.none)
		}
		
		/* We split the emails around the newline: AFAICT a newline is always invalid in an email adresse, whatever RFC you use to parse them.
		 * Usually emails are separated by a comma, but a comma _can_ be in a valid email and we’d have to properly parse stuff to extract the different email addresses. */
		let splitHint = hint.split(separator: "\n")
		
		struct Internal__InvalidEmailErrorMarker : Error {} /* Used as a marker if we encounter an invalid email. */
		let emails = try? splitHint.map{ try Email(rawValue: String($0)) ?! Internal__InvalidEmailErrorMarker() }
		
		if let emails {return emails}
		else          {return .none}
	}
	
	private static func setValueIfNeeded<T : Equatable>(_ val: T, in dest: inout T) -> Bool {
		guard val != dest else {
			return false
		}
		dest = val
		return true
	}
	
}
