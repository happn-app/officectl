/*
 * _LDAPAttribute.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import UnwrapOrThrow

import OfficeKit



protocol LDAPAttribute {
	
	associatedtype Value
	
	/** The object class containing the attribute. */
	static var objectClass: LDAPClass.Type {get}
	
	/** The descr OID form of the attribute. */
	static var descr: LDAPObjectID.Descr {get}
	/** The numericoid OID form of the attribute. */
	static var numericoid: LDAPObjectID.Numericoid {get}
	
	/** Converts the raw LDAP value to the attribute’s type. */
	static func value(from ldapValue: [Data]) throws -> Value
	/** Converts the attribute’s type to the raw LDAP value. */
	static func ldapValue(from value: Value) throws -> [Data]
	
}


extension LDAPAttribute {
	
	static var descrOID: LDAPObjectID {
		return .descr(descr)
	}
	
	static var numericoidOID: LDAPObjectID {
		return .numericoid(numericoid)
	}
	
	static var oidPair: (LDAPObjectID.Descr, LDAPObjectID.Numericoid) {
		return (descr, numericoid)
	}
	
}

	
extension LDAPAttribute {
	
	static func value(in record: LDAPRecord, checkClass: Bool = true) throws -> Value? {
		guard let v = record.valueFor(oidPair: (descr, numericoid), expectedObjectClassName: checkClass ? objectClass.name : nil) else {
			return nil
		}
		return try value(from: v)
	}
	
	@discardableResult
	static func setValueIfNeeded(_ value: Value, in record: inout LDAPRecord, checkClass: Bool = true, allowAddingClass: Bool = true) throws -> Bool {
		let ldapValue = try ldapValue(from: value)
		return try record.setValueIfNeeded(ldapValue, for: descrOID, numericoid: numericoid, expectedObjectClassName: checkClass ? objectClass.name : nil, allowAddingClass: allowAddingClass)
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
	
	static func ldapValue(from value: String) throws -> [Data] {
		return [Data(value.utf8)]
	}
	
	@discardableResult
	static func setValueIfNeeded(_ value: String, in record: inout LDAPRecord, checkClass: Bool = true) -> Bool {
		let ldapValue = [Data(value.utf8)]
		return record.setValueIfNeeded(ldapValue, for: descrOID, numericoid: numericoid, expectedObjectClassName: checkClass ? objectClass.name : nil)
	}
	
}


extension LDAPAttribute where Value == [String] {
	
	static func value(from ldapValue: [Data]) throws -> [String] {
		return try stringValues(for: ldapValue)
	}
	
	static func ldapValue(from value: [String]) throws -> [Data] {
		return value.map{ Data($0.utf8) }
	}
	
	@discardableResult
	static func setValueIfNeeded(_ value: [String], in record: inout LDAPRecord, checkClass: Bool = true) -> Bool {
		let ldapValue = value.map{ Data($0.utf8) }
		return record.setValueIfNeeded(ldapValue, for: descrOID, numericoid: numericoid, expectedObjectClassName: checkClass ? objectClass.name : nil)
	}
	
}
