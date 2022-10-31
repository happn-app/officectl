/*
 * OfficeService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/24.
 */

import Foundation

import GenericJSON



public protocol OfficeService : AnyObject, Sendable {
	
	/**
	 The ID of the linked provider, e.g. `OpenLDAP`.
	 This ID cannot be empty (reserved for the dummy provider). */
	static var providerID: String {get}
	
	init(id: String, jsonConfig: JSON) throws
	var id: String {get}
	
}


/* This is possible, and works, but is almost never what we want.
 * Instead we have to create the extension for all the OfficeService protocols. */
//public extension Dictionary {
//
//	subscript<T : OfficeService>(_ service: T) -> Value? where Key == DeportedHashability<T> {
//		get {self[.init(value: service, valueID: service.id)]}
//		set {self[.init(value: service, valueID: service.id)] = newValue}
//	}
//
//}
public extension Dictionary where Key == DeportedHashability<any OfficeService> {
	
	subscript(_ service: any OfficeService) -> Value? {
		get {self[.init(value: service, valueID: service.id)]}
		set {self[.init(value: service, valueID: service.id)] = newValue}
	}
	
}


public extension DeportedHashability where ValueType == any OfficeService {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.id)
	}
	
}

public extension DeportedHashability where ValueType : OfficeService {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.id)
	}
	
}
