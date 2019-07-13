/*
 * DirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public protocol DirectoryUser {
	
	associatedtype UserIdType : Hashable
	associatedtype PersistentIdType : Hashable
	
	var userId: UserIdType {get}
	var persistentId: RemoteProperty<PersistentIdType> {get}
	
	var emails: RemoteProperty<[Email]> {get}
	
	var firstName: RemoteProperty<String?> {get}
	var lastName: RemoteProperty<String?> {get}
	var nickname: RemoteProperty<String?> {get}
	
}


public enum DirectoryUserProperty : RawRepresentable, Hashable, ExpressibleByStringLiteral {
	
	public typealias RawValue = String
	public typealias StringLiteralType = String
	
	case userId
	case persistentId
	
	case emails
	
	case firstName
	case lastName
	case nickname
	
	case password
	
	case custom(String)
	
	public init(stringLiteral value: String) {
		switch value {
		case "userId":       self = .userId
		case "persistentId": self = .persistentId
		case "emails":       self = .emails
		case "firstName":    self = .firstName
		case "lastName":     self = .lastName
		case "nickname":     self = .nickname
		case "password":     self = .password
		default:             self = .custom(value)
		}
	}
	
	public init?(rawValue: String) {
		self.init(stringLiteral: rawValue)
	}
	
	public var rawValue: String {
		switch self {
		case .userId:        return "userId"
		case .persistentId:  return "persistentId"
		case .emails:        return "emails"
		case .firstName:     return "firstName"
		case .lastName:      return "lastName"
		case .nickname:      return "nickname"
		case .password:      return "password"
		case .custom(let v): return v
		}
	}
	
}
