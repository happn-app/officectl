/*
 * _LDAPAttribute.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import UnwrapOrThrow

import OfficeKit2



/* Sometime the numericoid or description can be unknown, but this describes the properties we **do** know.
 * NOT related to <https://tools.ietf.org/html/rfc4512#section-2.5> (we should rename the struct). */
struct AttributeDescription {
	
	let descr: LDAPObjectID.Descr
	let numericoid: LDAPObjectID.Numericoid
	
	init(_ descr: LDAPObjectID.Descr, _ numericoid: LDAPObjectID.Numericoid) {
		self.descr = descr
		self.numericoid = numericoid
	}
	
	var descrOID: LDAPObjectID {
		.descr(descr)
	}
	
	var numericoidOID: LDAPObjectID {
		.numericoid(numericoid)
	}
	
}


protocol LDAPAttribute {
	
	associatedtype Value
	static var attributeDescription: AttributeDescription {get}
	static func value(from ldapValue: [Data]) throws -> Value
	
}


extension LDAPAttribute {
	
	static func value(in record: LDAPRecord) throws -> Value? {
		/* TODO: Should we check the object classes?
		 *       Probably, but we do not have access to the class the property belong to here… */
		guard let v = record[attributeDescription.descrOID] ?? record[attributeDescription.numericoidOID] else {
			return nil
		}
		return try value(from: v)
	}
	
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
