/*
 * DirectoryUserProperty.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/19.
 */

import Foundation



/**
 A directory user property.
 
 Tested:
 ```
 let a = DirectoryUserProperty.id
 let b = DirectoryUserProperty.custom("id")
 a           == b           /* <-- This is true. */
 a.hashValue == b.hashValue /* <-- This is true. */
 ``` */
public enum DirectoryUserProperty : Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral, Codable {
	
	public typealias RawValue = String
	public typealias StringLiteralType = String
	
	case id
	case persistentID
	
	case identifyingEmails
	case otherEmails
	
	case firstName
	case lastName
	case nickname
	
	case password
	
	case custom(String)
	
	public init(stringLiteral value: String) {
		switch value {
			case "id":                self = .id
			case "persistentID":      self = .persistentID
			case "identifyingEmails": self = .identifyingEmails
			case "otherEmails":       self = .otherEmails
			case "firstName":         self = .firstName
			case "lastName":          self = .lastName
			case "nickname":          self = .nickname
			case "password":          self = .password
			default:                  self = .custom(value)
		}
	}
	
	public init?(rawValue: String) {
		self.init(stringLiteral: rawValue)
	}
	
	public var rawValue: String {
		switch self {
			case .id:                return "id"
			case .persistentID:      return "persistentID"
			case .identifyingEmails: return "identifyingEmails"
			case .otherEmails:       return "otherEmails"
			case .firstName:         return "firstName"
			case .lastName:          return "lastName"
			case .nickname:          return "nickname"
			case .password:          return "password"
			case .custom(let v):     return v
		}
	}
	
	/**
	 Even though `.id == .custom("id")` (and the same applies for hash values),
	  when switching on a value from this enum,
	  we should prefer switching on the normalized value as the case `.id` and `.custom("id")` are indeed different. */
	public func normalized() -> DirectoryUserProperty {
		if case .custom(let v) = self {
			return DirectoryUserProperty(stringLiteral: v)
		}
		return self
	}
	
}
