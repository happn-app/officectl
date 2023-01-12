/*
 * LDAPAttributeDescription.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2023/01/07.
 */

import Foundation



/* <https://tools.ietf.org/html/rfc4512#section-2.5> */
public struct LDAPAttributeDescription : RawRepresentable, Codable, Sendable {
	
	public static let uid = LDAPAttributeDescription(rawValue: "uid")!
	public static let mail = LDAPAttributeDescription(rawValue: "mail")!
	public static let memberof = LDAPAttributeDescription(rawValue: "memberof")!
	
	public var oid: LDAPObjectID
	/**
	 Each option must be one or more keychar (alphanumeric or a hyphen).
	 The options must be changed via the `setOptions` method.
	 This is to have a validation of the options before they are changed (the method can fail). */
	public private(set) var options: [String]
	
	public init?(stringOID: String, options: [String] = []) {
		guard let o = LDAPObjectID(rawValue: stringOID) else {
			return nil
		}
		self.oid = o
		
		/* Let’s validate the options. */
		guard LDAPAttributeDescription.validateOptions(options) else {
			return nil
		}
		self.options = options
	}
	
	public init?(rawValue: String) {
		let split = rawValue.split(separator: ";").map(String.init)
		self.init(stringOID: split[0], options: Array(split.dropFirst()))
	}
	
	public var rawValue: String {
		return options.reduce(oid.rawValue, { $0 + ";" + $1 })
	}
	
	/** Set new options in the attribute description. */
	public mutating func setOptions(_ newOptions: [String]) throws {
		guard LDAPAttributeDescription.validateOptions(newOptions) else {
			throw Err.ldapInvalidAttributeDescriptionOptions(newOptions)
		}
		options = newOptions
	}
	
	private static func validateOptions(_ options: [String]) -> Bool {
		for option in options {
			guard !option.isEmpty else {
				/* An option cannot be empty. */
				return false
			}
			guard option.rangeOfCharacter(from: CharacterSet.ldapKeycharCharset.inverted, options: [.literal]) == nil else {
				/* Invalid character found in option. */
				return false
			}
		}
		return true
	}
	
}
