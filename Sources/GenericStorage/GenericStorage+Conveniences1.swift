/*
 * GenericStorage+Level1Conveniences.swift
 * GenericStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



/* A good candidate for code generation… */
public extension GenericStorage {
	
	func storage(forKey key: String, currentKeyPath: [String] = []) throws -> GenericStorage {
		guard let s = storage(forKey: key) else {
			throw Error.missingValue(keyPath: currentKeyPath + [key])
		}
		return s
	}
	
	func optionalNonNullStorage(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> GenericStorage? {
		guard let s = storage(forKey: key) else {
			if errorOnMissingKey {throw Error.missingValue(keyPath: currentKeyPath + [key])}
			else                 {return nil}
		}
		guard !s.isNull else {
			return nil
		}
		return s
	}
	
	func null(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws {
		guard let s = storage(forKey: key) else {
			if errorOnMissingKey {throw Error.missingValue(keyPath: currentKeyPath + [key])}
			else                 {return}
		}
		guard s.isNull else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
	}
	
	func bool(forKey key: String, currentKeyPath: [String] = []) throws -> Bool {
		guard let b = try optionalBool(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return b
	}
	func optionalBool(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> Bool? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let b = s.boolValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return b
	}
	
	func int(forKey key: String, currentKeyPath: [String] = []) throws -> Int {
		guard let i = try optionalInt(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return i
	}
	func optionalInt(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> Int? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let i = s.intValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return i
	}
	
	func float(forKey key: String, currentKeyPath: [String] = []) throws -> Float {
		guard let f = try optionalFloat(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return f
	}
	func optionalFloat(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> Float? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let f = s.floatValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return f
	}
	
	func double(forKey key: String, currentKeyPath: [String] = []) throws -> Double {
		guard let d = try optionalDouble(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return d
	}
	func optionalDouble(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> Double? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let d = s.doubleValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return d
	}
	
	func string(forKey key: String, currentKeyPath: [String] = []) throws -> String {
		guard let s = try optionalString(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return s
	}
	func optionalString(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> String? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let str = s.stringValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return str
	}
	
	func url(forKey key: String, currentKeyPath: [String] = []) throws -> URL {
		guard let u = try optionalURL(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return u
	}
	func optionalURL(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> URL? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let u = s.urlValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return u
	}
	
	func data(forKey key: String, currentKeyPath: [String] = []) throws -> Data {
		guard let d = try optionalData(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return d
	}
	func optionalData(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> Data? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let d = s.dataValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return d
	}
	
	func array(forKey key: String, currentKeyPath: [String] = []) throws -> [GenericStorage] {
		guard let a = try optionalArray(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return a
	}
	func optionalArray(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> [GenericStorage]? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let a = s.arrayValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return a
	}
	
	func dictionary(forKey key: String, currentKeyPath: [String] = []) throws -> [String: GenericStorage] {
		guard let d = try optionalDictionary(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return d
	}
	func optionalDictionary(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> [String: GenericStorage]? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		guard let d = s.dictionaryValue else {
			throw Error.unexpectedType(actualValue: s, keyPath: currentKeyPath + [key])
		}
		return d
	}
	
}
