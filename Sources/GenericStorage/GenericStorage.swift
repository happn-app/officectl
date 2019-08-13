/*
 * GenericStorage.swift
 * officectl
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



public protocol GenericStorage {
	
	func storage(forKey key: String) -> GenericStorage?
	
	var isNull: Bool {get}
	
	var boolValue: Bool? {get}
	
	var intValue: Int? {get}
	var floatValue: Float? {get}
	var doubleValue: Double? {get}
	
	var stringValue: String? {get}
	var urlValue: URL? {get}
	
	var dataValue: Data? {get}
	
	var arrayValue: [GenericStorage]? {get}
	var dictionaryValue: [String: GenericStorage]? {get}
	
}


internal extension GenericStorage {
	
	func optionalStorage(forKey key: String) throws -> GenericStorage? {
		guard let s = storage(forKey: key) else {
			throw Error.missingValue
		}
		guard !s.isNull else {
			return nil
		}
		return s
	}
	
}
