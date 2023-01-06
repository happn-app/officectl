/*
 * _LDAPAttribute.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import UnwrapOrThrow

import OfficeKit2



enum AttributeDescription {
	
	case knownDescr(LDAPObjectID.Descr)
	case knownNumericoid(LDAPObjectID.Numericoid)
	case knownDescrAndNumericoid(LDAPObjectID.Descr, LDAPObjectID.Numericoid)
	
	var descr: LDAPObjectID.Descr? {
		switch self {
			case .knownDescr(let descr), .knownDescrAndNumericoid(let descr, _): return descr
			case .knownNumericoid:                                               return nil
		}
	}
	
	var numericoid: LDAPObjectID.Numericoid? {
		switch self {
			case .knownNumericoid(let n), .knownDescrAndNumericoid(_, let n): return n
			case .knownDescr:                                                 return nil
		}
	}
	
	var stringValue: String {
		/* descr is preferred as per the RFC. */
		switch self {
			case let .knownDescr(descr), let .knownDescrAndNumericoid(descr, _): return descr.rawValue
			case let .knownNumericoid(num):                                      return num.rawValue
		}
	}
	
}


protocol LDAPAttribute {
	
	associatedtype Value
	static var attributeDescription: AttributeDescription {get}
	static func value(from ldapValue: [Data]) throws -> Value
	
}


extension LDAPAttribute {
	
	static func singleValue(for value: [Data]) throws -> Data {
		return try value.onlyElement ?! Err.valueIsNotSingleData
	}
	
	static func singleStringValue(for value: [Data]) throws -> String {
		return try String(data: singleValue(for: value), encoding: .utf8) ?! Err.valueIsNotSingleString
	}
	
	static func stringValues(for value: [Data]) throws -> [String] {
		return try value.map{ try String(data: $0, encoding: .utf8) ?! Err.valueIsNotStrings }
	}
	
	/** Return the first value which has a valid UTF-8 string representation. */
	static func firstStringValue(for value: [Data]) throws -> String {
		return try value.lazy.compactMap{ String(data: $0, encoding: .utf8) }.first{ _ in true } ?! Err.valueIsDoesNotContainStrings
	}
	
}


extension LDAPAttribute where Value == String {
	
	static func value(from ldapValue: [Data]) throws -> String {
		return try singleStringValue(for: ldapValue)
	}
	
}


extension LDAPAttribute where Value == [String] {
	
	static func value(from ldapValue: [Data]) throws -> [String] {
		return try stringValues(for: ldapValue)
	}
	
}
