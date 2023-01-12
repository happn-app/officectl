/*
 * DirectoryUserWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/09.
 */

import Foundation

import Email
@preconcurrency import GenericJSON
import Logging
import UnwrapOrThrow

import OfficeModel



public struct DirectoryUserWrapper : DirectoryUser, Codable {
	
	public typealias IDType = TaggedID
	public typealias PersistentIDType = TaggedID
	
	public var userID: TaggedID
	@RemoteProperty
	public var persistentID: TaggedID?
	public var remotePersistentID: RemoteProperty<TaggedID> {_persistentID}
	
	@RemoteProperty
	public var identifyingEmail: Email??
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {_identifyingEmail}
	@RemoteProperty
	public var otherEmails: [Email]?
	public var remoteOtherEmails: RemoteProperty<[Email]> {_otherEmails}
	
	@RemoteProperty
	public var firstName: String??
	public var remoteFirstName: RemoteProperty<String?> {_firstName}
	@RemoteProperty
	public var lastName: String??
	public var remoteLastName: RemoteProperty<String?> {_lastName}
	@RemoteProperty
	public var nickname: String??
	public var remoteNickname: RemoteProperty<String?> {_nickname}
	
	/* Note: We could use GenericStorage, but this would complexify conformance to Codable so we’ll keep JSON, at least for now. */
	public var underlyingUser: JSON?
	
	/**
	 An attempt at something at some point.
	 Can probably be removed (set to private in the mean time). */
	private var savedHints = [DirectoryUserProperty: String?]()
	
	public var sourceServiceID: String {
		return userID.tag
	}
	
	public init(userID uid: TaggedID, persistentID pId: TaggedID? = nil, underlyingUser u: JSON? = nil, hints: [DirectoryUserProperty: String?] = [:]) {
		if TaggedID(string: uid.rawValue) != uid {
			OfficeKitConfig.logger?.error("Initing a DirectoryUserWrapper with a TaggedID whose string representation does not converts back to itself: \(uid)")
		}
		userID = uid
		_persistentID = pId.map{ .set($0) } ?? .unsupported
		
		underlyingUser = u
		savedHints = hints
	}
	
	public init(copying other: DirectoryUserWrapper) {
		userID = other.userID
		_persistentID = other._persistentID
		
		_identifyingEmail = other._identifyingEmail
		_otherEmails = other._otherEmails
		
		_firstName = other._firstName
		_lastName = other._lastName
		_nickname = other._nickname
		
		underlyingUser = other.underlyingUser
	}
	
	public init(json: JSON, forcedUserID: TaggedID?) throws {
		underlyingUser = json[CodingKeys.underlyingUser.rawValue]
		savedHints = json[CodingKeys.savedHints.rawValue]?.objectValue?.mapKeys{ DirectoryUserProperty(stringLiteral: $0) }.compactMapValues{ $0.stringValue } ?? [:]
		
		userID = try forcedUserID ?? TaggedID(string: json.string(forKey: CodingKeys.userID.rawValue))
		_persistentID = try json.optionalString(forKey: CodingKeys.persistentID.rawValue, errorOnMissingKey: false).flatMap{ .set(TaggedID(string: $0)) } ?? .unsupported
		
		_identifyingEmail = try json.optionalString(forKey: CodingKeys.identifyingEmail.rawValue, errorOnMissingKey: false).flatMap{ try .set(Email(rawValue: $0) ?! Err.genericError("Invalid email \($0) when initializing a DirectoryUserWrapper from JSON")) } ?? .unsupported
		_otherEmails = (try json.optionalArrayOfStrings(forKey: CodingKeys.otherEmails.rawValue, errorOnMissingKey: false)?.map{ try Email(rawValue: $0) ?! Err.genericError("Invalid email \($0) when initializing a DirectoryUserWrapper from JSON") }).flatMap{ .set($0) } ?? .unsupported
		
		if (try? json.null(forKey: CodingKeys.firstName.rawValue)) != nil {
			_firstName = .set(nil)
		} else {
			_firstName = try json.optionalString(forKey: CodingKeys.firstName.rawValue, errorOnMissingKey: false).flatMap{ .set($0) } ?? .unsupported
		}
		if (try? json.null(forKey: CodingKeys.lastName.rawValue)) != nil {
			_lastName = .set(nil)
		} else {
			_lastName = try json.optionalString(forKey: CodingKeys.lastName.rawValue, errorOnMissingKey: false).flatMap{ .set($0) } ?? .unsupported
		}
		if (try? json.null(forKey: CodingKeys.nickname.rawValue)) != nil {
			_nickname = .set(nil)
		} else {
			_nickname = try json.optionalString(forKey: CodingKeys.nickname.rawValue, errorOnMissingKey: false).flatMap{ .set($0) } ?? .unsupported
		}
	}
	
	public func json(includeSavedHints: Bool = false) -> JSON {
		var res: [String: JSON] = [
			CodingKeys.userID.rawValue: .string(userID.stringValue)
		]
		
		if let u = underlyingUser {res[CodingKeys.underlyingUser.rawValue] = u}
		if includeSavedHints {res[CodingKeys.savedHints.rawValue] = .object(savedHints.mapKeys{ $0.rawValue }.mapValues{ $0.flatMap{ .string($0) } ?? .null })}
		
		/* userId added above. */
		if let pId = persistentID {res[CodingKeys.persistentID.rawValue] = .string(pId.stringValue)}
		
		if let e = identifyingEmail {res[CodingKeys.identifyingEmail.rawValue] = e.flatMap{ .string($0.rawValue) } ?? .null}
		if let e = otherEmails      {res[CodingKeys.otherEmails.rawValue]      = .array(e.map{ .string($0.rawValue) })}
		
		if let fn = firstName {res[CodingKeys.firstName.rawValue] = fn.flatMap{ .string($0) } ?? .null}
		if let ln = lastName  {res[CodingKeys.lastName.rawValue]  = ln.flatMap{ .string($0) } ?? .null}
		if let nn = nickname  {res[CodingKeys.nickname.rawValue]  = nn.flatMap{ .string($0) } ?? .null}
		
		return .object(res)
	}
	
	public mutating func copyStandardNonIDProperties<U : DirectoryUser>(fromUser user: U) {
		_identifyingEmail = user.remoteIdentifyingEmail
		_otherEmails = user.remoteOtherEmails
		
		_firstName = user.remoteFirstName
		_lastName = user.remoteLastName
		_nickname = user.remoteNickname
	}
	
	public func applyingAndSavingHints(_ hints: [DirectoryUserProperty: String?], blacklistedKeys: Set<DirectoryUserProperty> = [.userID], replaceAllPreviouslySavedHints: Bool = false) -> DirectoryUserWrapper {
		var ret = DirectoryUserWrapper(copying: self)
		ret.applyAndSaveHints(hints, blacklistedKeys: blacklistedKeys, replaceAllPreviouslySavedHints: replaceAllPreviouslySavedHints)
		return ret
	}
	
	/**
	 Applies the hints it can, and trump all saved hints with the new ones.
	 If `replaceAllPreviouslySavedHints` is `true`, will also delete previously saved hints in the user.
	 Blacklisted keys are not saved.
	 
	 - Returns: The keys that have been modified. */
	@discardableResult
	public mutating func applyAndSaveHints(_ hints: [DirectoryUserProperty: String?], blacklistedKeys: Set<DirectoryUserProperty> = [.userID], replaceAllPreviouslySavedHints: Bool = false) -> Set<DirectoryUserProperty> {
		if replaceAllPreviouslySavedHints {
			savedHints = [:]
		}
		
		var modifiedKeys = Set<DirectoryUserProperty>()
		for (k, v) in hints {
			guard !blacklistedKeys.contains(k) else {continue}
			
			savedHints[k] = v
			
			var touchedKey = true
			switch k {
				case .userID:       if let v = v {userID = TaggedID(string: v)}
				case .persistentID: persistentID = v.flatMap{ TaggedID(string: $0) }
					
				case .identifyingEmail:
					let e = v.flatMap{ Email(rawValue: $0) }
					guard e != nil || v == nil else {
						OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value is an invalid email: \(String(describing: v))")
						continue
					}
					identifyingEmail = e
					
				case .otherEmails:
					/* Yes.
					 * We cannot represent an element in the list which contains a comma.
					 * Maybe one day we’ll do the generic thing… */
					let e = try? v.flatMap{ v -> [Email] in
						let l = v.split(separator: ",")
						return try l.map{ try Email(rawValue: String($0)) ?! Err.genericError("Invalid error. If you see this, see the dev; it should not happen.") }
					}
					guard e != nil || v == nil else {
						OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value has invalid email(s): \(String(describing: v))")
						continue
					}
					otherEmails = e
					
				case .firstName: firstName = v
				case .lastName:  lastName = v
				case .nickname:  nickname = v
					
				default:
					OfficeKitConfig.logger?.warning("Cannot apply hint for key \(k): value has not a compatible type or key is unknown: \(String(describing: v))")
					touchedKey = false
			}
			if touchedKey {modifiedKeys.insert(k)}
		}
		return modifiedKeys
	}
	
	public func mainEmail(domainMap: [String: String] = [:]) -> Email? {
		return identifyingEmail?.flatMap{ $0.primaryDomainVariant(aliasMap: domainMap) }
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum CodingKeys : String, CodingKey {
		case underlyingUser
		case savedHints
		
		case userID, persistentID
		case identifyingEmail, otherEmails
		case firstName, lastName, nickname
	}
	
}
