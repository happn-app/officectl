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
