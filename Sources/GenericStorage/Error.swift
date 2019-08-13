/*
 * Error.swift
 * GenericKeyedStorage
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



enum Error : Swift.Error {
	
	case missingValue
	case unexpectedNil
	case unexpectedType(actualValue: GenericStorage)
	case unexpectedTypeInArray(index: Int, actualValue: GenericStorage)
	case unexpectedTypeInDictionary(key: String, actualValue: GenericStorage)
	
}
