/*
 * LDAPObjectID.swift
 * OfficeKit
 *
 * Created by François Lamboley on 07/09/2018.
 */

import Foundation



public struct LDAPObjectID : Hashable {
	
	public let stringValue: String
	public let numericoidValues: [UInt]?
	
	/**
	Init the object id with an OID string.
	
	An OID must be a “numericoid” or a “description”. Where:
	- “description” is a keystring (an alphanumeric string that can contain
	hyphens and starts with a letter);
	- “numericoid” is something like “1.2.3” (must at least have two numbers;
	e.g. “1.1”). */
	public init?(oid: String) {
		/* Let’s validate the oid */
		if oid.contains(".") {
			/* We should have a numericoid */
			guard oid.rangeOfCharacter(from: CharacterSet.ldapNumericoidCharset.inverted, options: [.literal]) == nil else {
				/* Invalid character found in numericoid */
				return nil
			}
			var numbers = [UInt]()
			let stringNumbers = oid.split(separator: ".")
			for stringNumber in stringNumbers {
				guard !stringNumber.isEmpty else {
					/* A valid number cannot be empty. */
					return nil
				}
				guard stringNumber.first != "0" || stringNumber.count == 1 else {
					/* A valid number must not start with a 0, or must **be** 0. */
					return nil
				}
				/* This is all the validation we need to do for the number! As we
				 * have validated earlier that there are no invalid numericoid
				 * chars in the string, we _know_ the number is valid. As a
				 * defensive programming technique, let’s assert it… */
				assert(stringNumber.rangeOfCharacter(from: CharacterSet.asciiNumbers.inverted, options: [.literal]) == nil)
				numbers.append(UInt(stringNumber)!)
			}
			stringValue = oid
			numericoidValues = numbers
		} else {
			/* We should have a description (keystring) */
			guard let firstScalar = oid.first?.unicodeScalars.first else {
				/* description cannot be empty */
				return nil
			}
			guard CharacterSet.asciiLetters.contains(firstScalar) else {
				/* description must start with a letter */
				return nil
			}
			guard oid.rangeOfCharacter(from: CharacterSet.ldapKeycharCharset.inverted, options: [.literal]) == nil else {
				/* Invalid character found in description */
				return nil
			}
			stringValue = oid
			numericoidValues = nil
		}
	}
	
	public static func ==(_ lhs: LDAPObjectID, _ rhs: LDAPObjectID) -> Bool {
		return lhs.stringValue == rhs.stringValue
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(stringValue)
	}
	
}
