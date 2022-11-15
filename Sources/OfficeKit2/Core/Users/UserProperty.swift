/*
 * UserProperty.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/19.
 */

import Foundation



public struct UserProperty : RawRepresentable, ExpressibleByStringLiteral, Sendable, Codable, Hashable, Equatable {
	
	public static let id = UserProperty(rawValue: "id")
	
	public static let emails = UserProperty(rawValue: "emails")
	
	public static let firstName = UserProperty(rawValue: "firstName")
	public static let lastName = UserProperty(rawValue: "lastName")
	public static let nickname = UserProperty(rawValue: "nickname")
	
	public static let password = UserProperty(rawValue: "password")
	
	public var rawValue: String
	
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
