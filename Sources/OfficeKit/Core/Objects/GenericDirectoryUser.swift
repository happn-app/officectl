/*
 * GenericDirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation

import GenericJSON
import Logging



public struct GenericDirectoryUser : DirectoryUser, Codable {
	
	public typealias UserIdType = TaggedId
	public typealias PersistentIdType = JSON
	
	public init(email: Email) {
		self.init(userId: TaggedId(tag: "email", id: email.stringValue))
	}
	
	public init(userId: TaggedId) {
		assert(TaggedId(rawValue: userId.rawValue) == userId)
		data = [DirectoryUserProperty.userId.rawValue: .string(userId.rawValue)]
	}
	
	public init(json: JSON, forcedUserId: TaggedId? = nil) throws {
		guard case .object(let object) = json else {
			throw InvalidArgumentError(message: "The given JSON is not an object.")
		}
		try self.init(jsonObject: object, forcedUserId: forcedUserId)
	}
	
	public init(jsonObject: [String: JSON], forcedUserId: TaggedId? = nil) throws {
		var jsonObject = jsonObject
		if let forcedUserId = forcedUserId {
			jsonObject[DirectoryUserProperty.userId.rawValue] = .string(forcedUserId.stringValue)
		}
		
		/* Object validation */
		guard jsonObject[DirectoryUserProperty.userId.rawValue] != nil else {
			throw InvalidArgumentError(message: "No value for the userId key")
		}
		for (k, v) in jsonObject {
			guard GenericDirectoryUser.validate(value: .set(v), for: k) else {
				throw InvalidArgumentError(message: "Invalid \(k) value")
			}
		}
		
		data = jsonObject
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let d = try container.decode([String: JSON].self)
		
		do                                  {try self.init(jsonObject: d)}
		catch let e as InvalidArgumentError {throw DecodingError.dataCorruptedError(in: container, debugDescription: e.message ?? "<Unknown error>")}
		catch                               {throw DecodingError.dataCorruptedError(in: container, debugDescription: "<Unknown error>")}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(data)
	}
	
	public subscript(key: DirectoryUserProperty) -> RemoteProperty<JSON> {
		get {return self[key.rawValue]}
		set {self[key.rawValue] = newValue}
	}
	
	public subscript(key: String) -> RemoteProperty<JSON> {
		get {return data[key].flatMap{ .set($0) } ?? .unsupported}
		set {
			guard GenericDirectoryUser.validate(value: newValue, for: key) else {
				OfficeKitConfig.logger?.error("Invalid value \(newValue) for a GenericDirectoryUser for key \(key). Not changing the value.")
				return
			}
			data[key] = newValue.value
		}
	}
	
	#warning("INFO: With Swift 5.1, no need for returns anymore in getters.")
	public var userId: TaggedId {
		get {return TaggedId(rawValue: data[DirectoryUserProperty.userId.rawValue]!.stringValue!)!}
		set {data[DirectoryUserProperty.userId.rawValue] = .string(newValue.rawValue)}
	}
	public var persistentId: RemoteProperty<JSON> {
		get {return self[DirectoryUserProperty.persistentId.rawValue]}
		set {self[DirectoryUserProperty.persistentId.rawValue] = newValue}
	}
	
	public var emails: RemoteProperty<[Email]> {
		get {return self[DirectoryUserProperty.emails.rawValue].map{ $0.arrayValue!.map{ Email(string: $0.stringValue!)! } }} /* Lot of forced unwraps, but it’s all verified upstream. */
		set {self[DirectoryUserProperty.emails.rawValue] = newValue.map{ JSON.array($0.map{ JSON.string($0.stringValue) }) }}
	}
	
	public var firstName: RemoteProperty<String?> {
		get {return self[DirectoryUserProperty.firstName.rawValue].map{ unsafeJSONToOptionalString($0) }}
		set {self[DirectoryUserProperty.firstName.rawValue] = newValue.map{ optionalStringToJSON($0) }}
	}
	public var lastName: RemoteProperty<String?> {
		get {return self[DirectoryUserProperty.lastName.rawValue].map{ unsafeJSONToOptionalString($0) }}
		set {self[DirectoryUserProperty.lastName.rawValue] = newValue.map{ optionalStringToJSON($0) }}
	}
	public var nickname: RemoteProperty<String?> {
		get {return self[DirectoryUserProperty.nickname.rawValue].map{ unsafeJSONToOptionalString($0) }}
		set {self[DirectoryUserProperty.nickname.rawValue] = newValue.map{ optionalStringToJSON($0) }}
	}
	
	public func json() -> JSON {
		return .object(data)
	}
	
	public mutating func applyHints(_ hints: [DirectoryUserProperty: Any?], blacklistedKeys: Set<DirectoryUserProperty> = [.userId]) {
		for (k, v) in hints {
			guard !blacklistedKeys.contains(k) else {continue}
			do    {self[k.rawValue] = try v.flatMap{ .set(try JSON($0)) } ?? .unset}
			catch {/*nop*/}
		}
	}
	
	public mutating func takeStandardNonIdProperties<OtherUserType : DirectoryUser>(from otherUser: OtherUserType) {
		emails = otherUser.emails
		
		firstName = otherUser.firstName
		lastName = otherUser.lastName
		nickname = otherUser.nickname
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
		if let mainDomainEmails = mainDomainEmails, let e = mainDomainEmails.first, mainDomainEmails.count == 1 {
			return e
		}
		
		return nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static func validate(value: RemoteProperty<JSON>, for key: String) -> Bool {
		switch DirectoryUserProperty(stringLiteral: key) {
		case .userId:
			return value.value?.stringValue.flatMap{ TaggedId(rawValue: $0) } != nil
			
		case .firstName, .lastName, .nickname, .password:
			return value.map{ $0.stringValue != nil || $0.isNull }.value ?? true
			
		case .emails:
			guard let array = value.value?.arrayValue else {return false}
			return array.first{ $0.stringValue.flatMap{ Email(string: $0) } == nil } == nil
		
		case .persistentId, .custom: return true
		}
	}
	
	private var data: [String: JSON]
	
	private func unsafeJSONToOptionalString(_ json: JSON) -> String? {
		switch json {
		case .string(let str): return str
		case .null:            return nil
		default:
			fatalError("Asked to convert a non-string/non-nil JSON to an optional String!")
		}
	}
	
	private func optionalStringToJSON(_ str: String?) -> JSON {
		if let str = str {return .string(str)}
		return .null
	}
	
}
