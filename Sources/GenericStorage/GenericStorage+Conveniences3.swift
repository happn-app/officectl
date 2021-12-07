/*
 * GenericStorage+Conveniences3.swift
 * GenericStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



/* A good candidate for code generation… */
public extension GenericStorage {
	
	func dictionaryOfStringsValue(currentKeyPath: [String] = []) throws -> [String: String] {
		guard let o = dictionaryValue else {
			throw Error.unexpectedType(actualValue: self, keyPath: currentKeyPath)
		}
		var res = [String: String]()
		for (key, element) in o {
			guard let v = element.stringValue else {
				throw Error.unexpectedTypeInDictionary(key: key, actualValue: element, keyPath: currentKeyPath)
			}
			res[key] = v
		}
		return res
	}
	
	func dictionaryOfStrings(forKey key: String, currentKeyPath: [String] = []) throws -> [String: String] {
		guard let d = try optionalDictionaryOfStrings(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return d
	}
	func optionalDictionaryOfStrings(forKey key: String, errorOnMissingKey: Bool = true, currentKeyPath: [String] = []) throws -> [String: String]? {
		guard let s = try optionalNonNullStorage(forKey: key, errorOnMissingKey: errorOnMissingKey, currentKeyPath: currentKeyPath) else {
			return nil
		}
		return try s.dictionaryOfStringsValue(currentKeyPath: currentKeyPath + [key])
	}
	
}
