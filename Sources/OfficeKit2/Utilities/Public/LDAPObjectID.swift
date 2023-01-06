/*
 * LDAPObjectID.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/07.
 */

import Foundation



/* <https://www.alvestrand.no/objectid/>
 * <https://www.rfc-editor.org/rfc/rfc2252#section-4.1> */
public enum LDAPObjectID : Sendable, RawRepresentable {
	
	case numericoid(Numericoid)
	case descr(Descr)
	
	public struct Numericoid : Hashable, Sendable, RawRepresentable {
		
		/* Set is private to avoid the possibility of a client setting the invalid value (empty array). */
		public private(set) var values: [UInt]
		
		public var rawValue: String {
			return values.map(String.init).joined(separator: ".")
		}
		
		public init?(rawValue: String) {
			guard rawValue.rangeOfCharacter(from: CharacterSet.ldapNumericoidCharset.inverted, options: [.literal]) == nil else {
				/* Invalid character found in numericoid. */
				return nil
			}
			let stringNumbers = rawValue.split(separator: ".")
			
			self.values = [UInt]()
			for stringNumber in stringNumbers {
				guard !stringNumber.isEmpty else {
					/* A valid number cannot be empty. */
					return nil
				}
				/* This is all the validation we need to do for the number!
				 * As we have validated earlier that there are no invalid numericoid chars in the string, we _know_ the number is valid.
				 * As a defensive programming technique, let’s assert it… */
				assert(stringNumber.rangeOfCharacter(from: CharacterSet.asciiNumbers.inverted, options: [.literal]) == nil)
				/* About the force unwrap, we assume nobody will put a too big integer in the OID, yeah. */
				values.append(UInt(stringNumber)!)
			}
		}
		
	}
	
	public struct Descr : Hashable, Sendable, RawRepresentable {
		
		/* Set is private to avoid the possibility of a client setting an invalid value. */
		public private(set) var value: String
		
		public var rawValue: String {
			return value
		}
		
		public init?(rawValue: String) {
			guard let firstScalar = rawValue.first?.unicodeScalars.first else {
				/* description cannot be empty. */
				return nil
			}
			guard CharacterSet.asciiLetters.contains(firstScalar) else {
				/* description must start with a letter. */
				return nil
			}
			guard rawValue.rangeOfCharacter(from: CharacterSet.ldapKeycharCharset.inverted, options: [.literal]) == nil else {
				/* Invalid character found in description. */
				return nil
			}
			self.value = rawValue
		}
		
	}
	
	/**
	 Init the object ID with an OID string.
	 
	 An OID must be a “numericoid” or a “description” where:
	 - “description” is a keystring (an alphanumeric string that can contain hyphens and starts with a letter);
	 - “numericoid” is something like “1.2.3” (must at least have two numbers; e.g. “1.1”). */
	public init?(rawValue: String) {
		if rawValue.contains(".") {
			/* We should have a numericoid. */
			guard let numericoid = Numericoid(rawValue: rawValue) else {
				return nil
			}
			self = .numericoid(numericoid)
		} else {
			/* We should have a description (keystring) */
			guard let descr = Descr(rawValue: rawValue) else {
				return nil
			}
			self = .descr(descr)
		}
	}
	
	public var rawValue: String {
		switch self {
			case let .descr(descr):           return descr.rawValue
			case let .numericoid(numericoid): return numericoid.rawValue
		}
	}
	
}
