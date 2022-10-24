/*
 * OfficeService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/24.
 */

import Foundation

import GenericJSON



public protocol OfficeService : AnyObject {
	
	/**
	 The ID of the linked provider, e.g. `internal_openldap`.
	 
	 External provider IDs (not builtin to OfficeKit) must not have the `internal_` prefix. */
	static var providerID: String {get}
	
	init(jsonConfig: JSON) throws
	
}
