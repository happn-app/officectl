/*
 * UserAndServiceID.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2023/01/23.
 */

import Foundation

import OfficeModelCore

import ServiceKit



/**
 This is the binding between a user and a service.
 
 It is a protocol for technical reasons, for type erasure.
 
 The concrete implementation of this protocol is ``UserAndServiceIDImpl``.
 In general you should not need it.
 Instead you will use `any UserAndServiceID`.
 
 You can instantiate an erased `UserAndServiceID` from an erased user and service using ``UserAndServiceIDFrom(user:service:)``. */
public protocol UserAndServiceID<ServiceType> : Sendable, Hashable {
	
	associatedtype ServiceType : UserService
	
	var userID: ServiceType.UserType.UserIDType {get}
	var service: ServiceType {get}
	
}

public typealias HashableUserAndServiceID = DeportedHashability<any UserAndServiceID>
public extension DeportedHashability where ValueType == any UserAndServiceID {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.taggedID)
	}
	
}
public extension DeportedHashability where ValueType : UserAndServiceID {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.taggedID)
	}
	
}
