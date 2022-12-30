/*
 * LDAPAttributeDescription.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/07.
 */

import Foundation



/* <https://tools.ietf.org/html/rfc4512#section-1.4> */
public struct LDAPAttributeDescription : Hashable {
	
	public static let uid = LDAPAttributeDescription(string: "uid")!
	public static let mail = LDAPAttributeDescription(string: "mail")!
	public static let memberof = LDAPAttributeDescription(string: "memberof")!
	
	public var oid: LDAPObjectID
	/**
	 Each option must be one or more keychar (alphanumeric or a hyphen).
	 The options must be changed via the `setOptions` method.
	 This is to have a validation of the options before they are changed (the method can fail). */
	public private(set) var options: [String]
	
	public var stringValue: String {
		return oid.stringValue + options.reduce("", { $0 + ";" + $1 })
	}
	
	public init?(stringOID: String, options opts: [String] = []) {
		guard let o = LDAPObjectID(oid: stringOID) else {
			return nil
		}
		oid = o
		
		/* Let’s validate the options */
		guard LDAPAttributeDescription.validateOptions(opts) else {
			return nil
		}
		options = opts
	}
	
	public init?(string: String) {
		let split = string.split(separator: ";").map(String.init)
		self.init(stringOID: split[0], options: Array(split.dropFirst()))
	}
	
	/** Set new options in the attribute description. */
	public mutating func setOptions(_ newOptions: [String]) throws {
		guard LDAPAttributeDescription.validateOptions(newOptions) else {throw InvalidArgumentError()}
		options = newOptions
	}
	
	private static func validateOptions(_ options: [String]) -> Bool {
		for option in options {
			guard !option.isEmpty else {
				/* An option cannot be empty */
				return false
			}
			guard option.rangeOfCharacter(from: CharacterSet.ldapKeycharCharset.inverted, options: [.literal]) == nil else {
				/* Invalid character found in option */
				return false
			}
		}
		return true
	}
	
}
