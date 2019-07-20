/*
 * GenericDirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation

import GenericJSON
import Logging



public enum GenericDirectoryUserId : RawRepresentable, Hashable {
	
	public typealias RawValue = JSON
	
	case native(JSON)
	case proxy(serviceId: String, userId: String, user: JSON)
	
	public init?(rawValue: JSON) {
		guard let object = rawValue.objectValue else {return nil}
		guard object.count == 1 else {return nil}
		
		if let native = object["native"] {
			self = .native(native)
			
		} else if let proxy = object["proxy"]?.objectValue {
			guard proxy.count == 3 else {return nil}
			guard let user = proxy["user"] else {return nil}
			guard let userId = proxy["userId"]?.stringValue else {return nil}
			guard let serviceId = proxy["serviceId"]?.stringValue else {return nil}
			
			self = .proxy(serviceId: serviceId, userId: userId, user: user)
			
		} else {
			return nil
		}
	}
	
	public var rawValue: JSON {
		switch self {
		case .native(let j):                                                 return .object(["native": j])
		case .proxy(serviceId: let sid, userId: let userId, user: let user): return .object(["proxy": ["serviceId": .string(sid), "userId": .string(userId), "user": user]])
		}
	}
	
}


public struct GenericDirectoryUser : DirectoryUser, Codable {
	
	public typealias UserIdType = GenericDirectoryUserId
	public typealias PersistentIdType = JSON
	
	public init(userId: GenericDirectoryUserId) {
		assert(GenericDirectoryUserId(rawValue: userId.rawValue) != nil)
		data = [DirectoryUserProperty.userId.rawValue: userId.rawValue]
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		data = try container.decode([String: JSON].self)
		
		for (k, v) in data {
			guard GenericDirectoryUser.validate(value: .set(v), for: k) else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid \(k) value")
			}
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(data)
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
	public var userId: GenericDirectoryUserId {
		get {return GenericDirectoryUserId(rawValue: data[DirectoryUserProperty.userId.rawValue]!)!}
		set {data[DirectoryUserProperty.userId.rawValue] = newValue.rawValue}
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
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static func validate(value: RemoteProperty<JSON>, for key: String) -> Bool {
		switch DirectoryUserProperty(stringLiteral: key) {
		case .userId:
			return value.value.flatMap{ GenericDirectoryUserId(rawValue: $0) } != nil
			
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
