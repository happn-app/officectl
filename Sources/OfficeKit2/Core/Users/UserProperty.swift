/*
 * UserProperty.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/19.
 */

import Foundation



public struct UserProperty : RawRepresentable, ExpressibleByStringLiteral, Sendable, Codable, Hashable, Equatable {
	
	/**
	 The properties that are defined directly on the ``User`` protocol.
	 
	 This set of properties are automatically retrieved by a ``User`` extension when using `valueForProperty(_:)` w/o the concrete implementation having to do anything specific.
	 
	 `.password` is **not** a standard property _on purpose_ because:
	 - retrieving the password should generally not be possible;
	 - the password property does not exist in the ``User`` protocol;
	 - generally speaking setting the password should be done using a dedicated method. */
	public static let standardProperties: Set<UserProperty> = [
		.id, .persistentID,
		.isSuspended,
		.emails,
		.firstName, .lastName, .nickname
	]
	
	public static let id = UserProperty(rawValue: "id")
	public static let persistentID = UserProperty(rawValue: "persistent_id")
	
	public static let isSuspended = UserProperty(rawValue: "is_suspended")
	
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
