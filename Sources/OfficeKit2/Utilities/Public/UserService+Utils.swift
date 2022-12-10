/*
 * UserService+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/10.
 * 
 */

import Foundation

import OfficeModelCore



public extension UserService {
	
	/**
	 Returns the value for the property.
	 Always return either a `set` or `unsupported` property; never an `unset` one.
	 (I’m not sure we’ll keep the concept of an `unset` property…) */
	func valueForProperty(_ property: UserProperty, inUser user: UserType) -> RemoteProperty<AnyUserPropertyValue?> {
		guard supportedUserProperties.contains(property) else {
			return .unsupported
		}
		
		return .set(user.oU_valueForProperty(property))
	}
	
}
