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
	 The ID of the linked provider, e.g. `internal_openldap`.
	 
	 External provider IDs (not builtin to OfficeKit) must not have the `internal_` prefix. */
	static var providerID: String {get}
	
	init(id: String, jsonConfig: JSON) throws
	var id: String {get}
	
}


public extension DeportedHashability where ValueType : OfficeService {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.id)
	}
	
}
