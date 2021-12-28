/*
 * JSON+GenericStorage.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation

import GenericJSON
import GenericStorage



extension JSON : GenericStorage {
	
	public func storage(forKey key: String) -> GenericStorage? {
		return self[key]
	}
	
	public var intValue: Int? {
		return doubleValue.flatMap{ (f: Double) -> Int? in
			let i = Int(f)
			guard abs(f - Double(i)) < 0.00001 else {
				return nil
			}
			return i
		}
	}
	
	public var floatValue: Float? {
		return doubleValue.flatMap{ Float($0) }
	}
	
	public var urlValue: URL? {
		return stringValue.flatMap{ URL(string: $0) }
	}
	
	public var dataValue: Data? {
		return nil
	}
	
	public var arrayValue: [GenericStorage]? {
		/* Note: Don’t know how to access JSON’s original arrayValue var… */
		if case .array(let value) = self {
			return value
		}
		return nil
	}
	
	public var dictionaryValue: [String : GenericStorage]? {
		return objectValue
	}
	
}
