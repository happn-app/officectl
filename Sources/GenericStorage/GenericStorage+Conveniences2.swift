/*
 * GenericStorage+Level2Conveniences.swift
 * GenericStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



/* A good candidate for code generation… */
public extension GenericStorage {
	
	func arrayOfStringsValue() throws -> [String] {
		guard let a = arrayValue else {
			throw Error.unexpectedType(actualValue: self)
		}
		return try a.enumerated().map{
			let (idx, element) = $0
			guard let v = element.stringValue else {
				throw Error.unexpectedTypeInArray(index: idx, actualValue: element)
			}
			return v
		}
	}
	
	func arrayOfStrings(forKey key: String) throws -> [String] {
		guard let a = try optionalArrayOfStrings(forKey: key) else {
			throw Error.unexpectedNil
		}
		return a
	}
	func optionalArrayOfStrings(forKey key: String) throws -> [String]? {
		guard let s = try optionalStorage(forKey: key) else {
			return nil
		}
		return try s.arrayOfStringsValue()
	}
	
}
