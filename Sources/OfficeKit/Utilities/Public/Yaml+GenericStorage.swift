/*
 * Yaml+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 21/03/2019.
 */

import Foundation

import GenericStorage
import Yaml



extension Yaml : GenericStorage {
	
	public func storage(forKey key: String) -> GenericStorage? {
		return self[.string(key)]
	}
	
	public var isNull: Bool {
		if case .null = self {return true}
		return false
	}
	
	public var boolValue: Bool? {
		return bool
	}
	
	public var intValue: Int? {
		return int
	}
	
	public var floatValue: Float? {
		return double.flatMap{ Float($0) }
	}
	
	public var doubleValue: Double? {
		return double
	}
	
	public var stringValue: String? {
		return string
	}
	
	public var urlValue: URL? {
		return string.flatMap{ URL(string: $0) }
	}
	
	public var dataValue: Data? {
		return nil
	}
	
	public var arrayValue: [GenericStorage]? {
		return array
	}
	
	public var dictionaryValue: [String : GenericStorage]? {
		guard let d = dictionary else {return nil}
		
		var res = [String: Yaml]()
		for (k, v) in d {
			guard let s = k.string else {return nil}
			res[s] = v
		}
		return res
	}
	
}
