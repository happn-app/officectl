/*
 * UserAndService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import OfficeModelCore



/**
 This is the binding between a user and a service.
 
 It is a protocol for technical reasons, for type erasure.
 
 The concrete implementation of this protocol is ``UserAndServiceImpl``.
 In general you should not need it.
 Instead you will use `any UserAndService`.
 
 You can instantiate an erased `UserAndService` from an erased user and service using ``UserAndServiceFrom(user:service:)``. */
public protocol UserAndService<ServiceType> : Sendable, Hashable {
	
	associatedtype ServiceType : UserService
	
	var user: ServiceType.UserType {get}
	var service: ServiceType {get}
	
}

public typealias HashableUserAndService = DeportedHashability<any UserAndService>
public extension DeportedHashability where ValueType == any UserAndService {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.taggedID)
	}
	
}
public extension DeportedHashability where ValueType : UserAndService {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.taggedID)
	}
	
}
