/*
 * GenericStorage+Conveniences3.swift
 * GenericStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



/* A good candidate for code generation… */
public extension GenericStorage {
	
	func dictionaryOfStringsValue() throws -> [String: String] {
		guard let o = dictionaryValue else {
			throw Error.unexpectedType(actualValue: self)
		}
		var res = [String: String]()
		for (key, element) in o {
			guard let v = element.stringValue else {
				throw Error.unexpectedTypeInDictionary(key: key, actualValue: element)
			}
			res[key] = v
		}
		return res
	}
	
	func dictionaryOfStrings(forKey key: String) throws -> [String: String] {
		guard let d = try optionalDictionaryOfStrings(forKey: key) else {
			throw Error.unexpectedNil
		}
		return d
	}
	func optionalDictionaryOfStrings(forKey key: String) throws -> [String: String]? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		return try s.dictionaryOfStringsValue()
	}
	
}
