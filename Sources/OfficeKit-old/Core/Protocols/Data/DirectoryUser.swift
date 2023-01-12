/*
 * DirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/01.
 */

import Foundation

import Email

import OfficeModel



public protocol DirectoryUser : Sendable {
	
	associatedtype IDType : Hashable
	associatedtype PersistentIDType : Hashable
	
	var userID: IDType {get}
	var remotePersistentID: RemoteProperty<PersistentIDType> {get}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {get}
	var remoteOtherEmails: RemoteProperty<[Email]> {get}
	
//	var remoteFullName: RemoteProperty<String?> {get}
	var remoteFirstName: RemoteProperty<String?> {get}
	var remoteLastName: RemoteProperty<String?> {get}
	var remoteNickname: RemoteProperty<String?> {get}
	
}


extension DirectoryUser {
	
	public var persistentID: PersistentIDType? {remotePersistentID.wrappedValue}
	
	public var identifyingEmail: Email?? {remoteIdentifyingEmail.wrappedValue}
	public var otherEmails: [Email]? {remoteOtherEmails.wrappedValue}
	
	public var firstName: String?? {remoteFirstName.wrappedValue}
	public var lastName: String?? {remoteLastName.wrappedValue}
	public var nickname: String?? {remoteNickname.wrappedValue}
	
	public var emails: [Email] {
		return (remoteIdentifyingEmail.wrappedValue?.flatMap{ [$0] } ?? []) + (remoteOtherEmails.wrappedValue ?? [])
	}
	
}


/**
 A directory user property.
 
 Tested:
 ```
 let a = DirectoryUserProperty.userID
 let b = DirectoryUserProperty.custom("userID")
 a           == b           /* <-- This is true. */
 a.hashValue == b.hashValue /* <-- This is true. */
 ``` */
public enum DirectoryUserProperty : Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral, Codable {
	
	public typealias RawValue = String
	public typealias StringLiteralType = String
	
	case userID
	case persistentID
	
	case identifyingEmail
	case otherEmails
	
	case firstName
	case lastName
	case nickname
	
	case password
	
	case custom(String)
	
	public init(stringLiteral value: String) {
		switch value {
			case "userID":           self = .userID
			case "persistentID":     self = .persistentID
			case "identifyingEmail": self = .identifyingEmail
			case "otherEmails":      self = .otherEmails
			case "firstName":        self = .firstName
			case "lastName":         self = .lastName
			case "nickname":         self = .nickname
			case "password":         self = .password
			default:                 self = .custom(value)
		}
	}
	
	public init?(rawValue: String) {
		self.init(stringLiteral: rawValue)
	}
	
	public var rawValue: String {
		switch self {
			case .userID:           return "userID"
			case .persistentID:     return "persistentID"
			case .identifyingEmail: return "identifyingEmail"
			case .otherEmails:      return "otherEmails"
			case .firstName:        return "firstName"
			case .lastName:         return "lastName"
			case .nickname:         return "nickname"
			case .password:         return "password"
			case .custom(let v):    return v
		}
	}
	
	/**
	 Even though `.userID == .custom("userID")` (and the same applies for hash values),
	 when switching on a value from this enum,
	 we should prefer switching on the normalized value as the case `.userID` and `.custom("userID")` are indeed different. */
	public func normalized() -> DirectoryUserProperty {
		if case .custom(let v) = self {
			return DirectoryUserProperty(stringLiteral: v)
		}
		return self
	}
	
}
