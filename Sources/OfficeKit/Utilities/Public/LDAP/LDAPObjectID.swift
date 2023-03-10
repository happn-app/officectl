/*
 * LDAPObjectID.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/07.
 */

import Foundation



/* <https://www.alvestrand.no/objectid/>
 * <https://www.rfc-editor.org/rfc/rfc2252#section-4.1> */
public enum LDAPObjectID : Hashable, Sendable {
	
	case numericoid(Numericoid)
	case descr(Descr)
	
	public struct Numericoid : Hashable, Sendable {
		
		/* Set is private to avoid the possibility of a client setting the invalid value (empty array). */
		public private(set) var values: [UInt]
		
	}
	
	public struct Descr : Hashable, Sendable {
		
		/* Set is private to avoid the possibility of a client setting an invalid value. */
		public private(set) var value: String
		
	}
	
}


extension LDAPObjectID : RawRepresentable {
	
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


extension LDAPObjectID : Codable {

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let rawValue = try container.decode(String.self)
		guard let inited = Self(rawValue: rawValue) else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid raw value for an LDAPObjectID")
		}
		self = inited
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
	
}


extension LDAPObjectID.Numericoid : RawRepresentable {
	
	public init?(rawValue: String) {
		guard rawValue.rangeOfCharacter(from: CharacterSet.ldapNumericoidCharset.inverted, options: [.literal]) == nil else {
			/* Invalid character found in numericoid. */
			return nil
		}
		let stringNumbers = rawValue.split(separator: ".")
		
		self.values = [UInt]()
		for stringNumber in stringNumbers {
			guard !stringNumber.isEmpty, (stringNumber == "0" || !stringNumber.starts(with: "0")) else {
				/* A valid number cannot be empty, nor start with a 0 if it is not 0. */
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
	
	public var rawValue: String {
		return values.map(String.init).joined(separator: ".")
	}
	
}


extension LDAPObjectID.Numericoid : Codable {

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let rawValue = try container.decode(String.self)
		guard let inited = Self(rawValue: rawValue) else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid raw value for an OID Numericoid")
		}
		self = inited
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
	
}


extension LDAPObjectID.Descr : RawRepresentable {
	
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
	
	public var rawValue: String {
		return value
	}
	
}


extension LDAPObjectID.Descr : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let rawValue = try container.decode(String.self)
		guard let inited = Self(rawValue: rawValue) else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid raw value for an OID Descr")
		}
		self = inited
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
	
}
