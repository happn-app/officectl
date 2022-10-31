/*
 * UserAndService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import OfficeModelCore

import ServiceKit



/**
 This is the bound between a user and a service.
 
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


/**
 Retrieve an erased ``UserAndService`` from the given user and services.
 If the user does not come from the given service, returns `nil`.
 
 The underlying structure returned will be of type ``UserAndServiceImpl`` but that’s an implementation detail you should not care about. */
public func UserAndServiceFrom<UserType : User, ServiceType : UserService>(user: UserType, service: ServiceType) -> (any UserAndService)? {
	guard let user = user as? ServiceType.UserType else {
		return nil
	}
	return UserAndServiceImpl(user: user, service: service)
}


/**
 The concrete implementation of the ``UserAndService`` protocol. */
public struct UserAndServiceImpl<ServiceType : UserService> : UserAndService {
	
	public var user: ServiceType.UserType
	public var service: ServiceType
	
	public init(user: ServiceType.UserType, service: ServiceType) {
		self.user = user
		self.service = service
	}
	
	/* **************************
	   MARK: Hashable Conformance
	   ************************** */
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.taggedID == rhs.taggedID
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggedID)
	}
	
}
