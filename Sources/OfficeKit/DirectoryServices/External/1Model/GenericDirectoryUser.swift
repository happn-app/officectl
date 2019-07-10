/*
 * GenericDirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation

import GenericJSON



public enum GenericDirectoryUserId : RawRepresentable, Hashable {
	
	public typealias RawValue = JSON
	
	case native(JSON)
	case proxy(serviceId: String, user: JSON)
	
	public init?(rawValue: JSON) {
		guard let object = rawValue.objectValue else {return nil}
		guard object.count == 1 else {return nil}
		
		if let native = object["native"] {
			self = .native(native)
			
		} else if let proxy = object["proxy"]?.objectValue {
			guard proxy.count == 2 else {return nil}
			guard let user = proxy["user"] else {return nil}
			guard let serviceId = proxy["serviceId"]?.stringValue else {return nil}
			
			self = .proxy(serviceId: serviceId, user: user)
			
		} else {
			return nil
		}
	}
	
	public var rawValue: JSON {
		switch self {
		case .native(let j):                             return .object(["native": j])
		case .proxy(serviceId: let sid, user: let user): return .object(["proxy": ["serviceId": .string(sid), "user": user]])
		}
	}
	
}


public struct GenericDirectoryUser : DirectoryUser, Codable {
	
	public typealias UserIdType = GenericDirectoryUserId
	public typealias PersistentIdType = JSON
	
	public init(userId: GenericDirectoryUserId) {
		data = [DirectoryUserProperty.userId.rawValue: userId.rawValue]
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		data = try container.decode([String: JSON].self)
		
		guard let id = data[DirectoryUserProperty.userId.rawValue] else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Missing userId value")
		}
		guard GenericDirectoryUserId(rawValue: id) != nil else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid userId value")
		}
		if let emails = data[DirectoryUserProperty.emails.rawValue] {
			guard let jsonArray = emails.arrayValue else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value for key emails is not an array")
			}
			let strArray = jsonArray.compactMap{ $0.stringValue }
			guard strArray.count == jsonArray.count else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value for key emails contains a non-string element")
			}
			let emailsArray = strArray.compactMap{ Email(string: $0) }
			guard emailsArray.count == strArray.count else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value for key emails contains a non-valid email")
			}
		}
		if let firstName = data[DirectoryUserProperty.firstName.rawValue] {
			guard firstName.stringValue != nil || firstName.isNull else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value for key firstName is neither a string nor nil.")
			}
		}
		if let lastName = data[DirectoryUserProperty.lastName.rawValue] {
			guard lastName.stringValue != nil || lastName.isNull else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value for key lastName is neither a string nor nil.")
			}
		}
		if let nickname = data[DirectoryUserProperty.nickname.rawValue] {
			guard nickname.stringValue != nil || nickname.isNull else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value for key nickname is neither a string nor nil.")
			}
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(data)
	}
	
	public subscript(key: String) -> RemoteProperty<JSON> {
		get {data[key].flatMap{ .set($0) } ?? .unsupported}
		set {data[key] = newValue.value}
	}
	
	public var userId: GenericDirectoryUserId {
		get {GenericDirectoryUserId(rawValue: data[DirectoryUserProperty.userId.rawValue]!)!}
		set {data[DirectoryUserProperty.userId.rawValue] = newValue.rawValue}
	}
	public var persistentId: RemoteProperty<JSON> {
		get {self[DirectoryUserProperty.persistentId.rawValue]}
		set {self[DirectoryUserProperty.persistentId.rawValue] = newValue}
	}
	
	public var emails: RemoteProperty<[Email]> {
		get {self[DirectoryUserProperty.emails.rawValue].map{ $0.arrayValue!.map{ Email(string: $0.stringValue!)! } }} /* Lot of forced unwraps, but it’s all verified upstream. */
		set {self[DirectoryUserProperty.emails.rawValue] = newValue.map{ JSON.array($0.map{ JSON.string($0.stringValue) }) }}
	}
	
	public var firstName: RemoteProperty<String?> {
		get {self[DirectoryUserProperty.firstName.rawValue].map{ unsafeJSONToOptionalString($0) }}
		set {self[DirectoryUserProperty.firstName.rawValue] = newValue.map{ optionalStringToJSON($0) }}
	}
	public var lastName: RemoteProperty<String?> {
		get {self[DirectoryUserProperty.lastName.rawValue].map{ unsafeJSONToOptionalString($0) }}
		set {self[DirectoryUserProperty.lastName.rawValue] = newValue.map{ optionalStringToJSON($0) }}
	}
	public var nickname: RemoteProperty<String?> {
		get {self[DirectoryUserProperty.nickname.rawValue].map{ unsafeJSONToOptionalString($0) }}
		set {self[DirectoryUserProperty.nickname.rawValue] = newValue.map{ optionalStringToJSON($0) }}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
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
