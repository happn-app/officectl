/*
 * UserProperty.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/19.
 */

import Foundation



public struct UserProperty : RawRepresentable, ExpressibleByStringLiteral, Sendable, Codable, Hashable, Equatable {
	
	/** The properties that are defined directly on the ``User`` protocol. */
	public static let standardProperties: Set<UserProperty> = [
		.id,
		.emails,
		.firstName, .lastName, .nickname,
		.password
	]
	
	public static let id = UserProperty(rawValue: "id")
	public static let persistentID = UserProperty(rawValue: "persistent_id")
	
	public static let firstName = UserProperty(rawValue: "first_name")
	public static let lastName = UserProperty(rawValue: "last_name")
	public static let nickname = UserProperty(rawValue: "nickname")
	
	public static let emails = UserProperty(rawValue: "emails")
	
	public static let password = UserProperty(rawValue: "password")
	
	public var rawValue: String
	
	public var isStandard: Bool {
		return Self.standardProperties.contains(self)
	}
	
	public init(stringLiteral: String) {
		self.init(stringLiteral)
	}
	
	public init(rawValue: String) {
		self.init(rawValue)
	}
	
	public init(_ string: String) {
		self.rawValue = string
	}
	
}
