/*
 * GenericStorage+Level1Conveniences.swift
 * GenericStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



/* A good candidate for code generation… */
public extension GenericStorage {
	
	func null(forKey key: String) throws {
		guard let s = storage(forKey: key) else {
			throw Error.missingValue
		}
		guard s.isNull else {
			throw Error.unexpectedType(actualValue: s)
		}
	}
	
	func bool(forKey key: String) throws -> Bool {
		guard let b = try optionalBool(forKey: key) else {
			throw Error.unexpectedNil
		}
		return b
	}
	func optionalBool(forKey key: String) throws -> Bool? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let b = s.boolValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return b
	}
	
	func int(forKey key: String) throws -> Int {
		guard let i = try optionalInt(forKey: key) else {
			throw Error.unexpectedNil
		}
		return i
	}
	func optionalInt(forKey key: String) throws -> Int? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let i = s.intValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return i
	}
	
	func float(forKey key: String) throws -> Float {
		guard let f = try optionalFloat(forKey: key) else {
			throw Error.unexpectedNil
		}
		return f
	}
	func optionalFloat(forKey key: String) throws -> Float? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let f = s.floatValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return f
	}
	
	func double(forKey key: String) throws -> Double {
		guard let d = try optionalDouble(forKey: key) else {
			throw Error.unexpectedNil
		}
		return d
	}
	func optionalDouble(forKey key: String) throws -> Double? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let d = s.doubleValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return d
	}
	
	func string(forKey key: String) throws -> String {
		guard let s = try optionalString(forKey: key) else {
			throw Error.unexpectedNil
		}
		return s
	}
	func optionalString(forKey key: String) throws -> String? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let str = s.stringValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return str
	}
	
	func url(forKey key: String) throws -> URL {
		guard let u = try optionalURL(forKey: key) else {
			throw Error.unexpectedNil
		}
		return u
	}
	func optionalURL(forKey key: String) throws -> URL? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let u = s.urlValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return u
	}
	
	func data(forKey key: String) throws -> Data {
		guard let d = try optionalData(forKey: key) else {
			throw Error.unexpectedNil
		}
		return d
	}
	func optionalData(forKey key: String) throws -> Data? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let d = s.dataValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return d
	}
	
	func array(forKey key: String) throws -> [GenericStorage] {
		guard let a = try optionalArray(forKey: key) else {
			throw Error.unexpectedNil
		}
		return a
	}
	func optionalArray(forKey key: String) throws -> [GenericStorage]? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let a = s.arrayValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return a
	}
	
	func dictionary(forKey key: String) throws -> [String: GenericStorage] {
		guard let d = try optionalDictionary(forKey: key) else {
			throw Error.unexpectedNil
		}
		return d
	}
	func optionalDictionary(forKey key: String) throws -> [String: GenericStorage]? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		guard let d = s.dictionaryValue else {
			throw Error.unexpectedType(actualValue: s)
		}
		return d
	}
	
}
