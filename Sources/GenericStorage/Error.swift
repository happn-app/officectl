/*
 * Error.swift
 * GenericKeyedStorage
 *
 * Created by François Lamboley on 2019/08/13.
 */

import Foundation



enum Error : Swift.Error {
	
	case missingValue(keyPath: [String])
	case unexpectedNil(keyPath: [String])
	case unexpectedType(actualValue: GenericStorage, keyPath: [String])
	case unexpectedTypeInArray(index: Int, actualValue: GenericStorage, keyPath: [String])
	case unexpectedTypeInDictionary(key: String, actualValue: GenericStorage, keyPath: [String])
	
}
