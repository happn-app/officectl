/*
 * GenericStorage+Level2Conveniences.swift
 * GenericStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



/* A good candidate for code generation… */
public extension GenericStorage {
	
	func arrayOfStringsValue(currentKeyPath: [String] = []) throws -> [String] {
		guard let a = arrayValue else {
			throw Error.unexpectedType(actualValue: self, keyPath: currentKeyPath)
		}
		return try a.enumerated().map{
			let (idx, element) = $0
			guard let v = element.stringValue else {
				throw Error.unexpectedTypeInArray(index: idx, actualValue: element, keyPath: currentKeyPath)
			}
			return v
		}
	}
	
	func arrayOfStrings(forKey key: String, currentKeyPath: [String] = []) throws -> [String] {
		guard let a = try optionalArrayOfStrings(forKey: key, currentKeyPath: currentKeyPath) else {
			throw Error.unexpectedNil(keyPath: currentKeyPath + [key])
		}
		return a
	}
	func optionalArrayOfStrings(forKey key: String, currentKeyPath: [String] = []) throws -> [String]? {
		guard let s = try optionalNonNullStorage(forKey: key, currentKeyPath: currentKeyPath) else {
			return nil
		}
		return try s.arrayOfStringsValue(currentKeyPath: currentKeyPath + [key])
	}
	
}
