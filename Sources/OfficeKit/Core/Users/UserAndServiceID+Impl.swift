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
 Retrieve an erased ``UserAndServiceID`` from the given user and services.
 If the user does not come from the given service, returns `nil`.
 
 The underlying structure returned will be of type ``UserAndServiceIDImpl`` but that’s an implementation detail you should not care about. */
public func UserAndServiceIDFrom<UserIDType : Hashable & Sendable, ServiceType : UserService>(userID: UserIDType, service: ServiceType) -> (any UserAndServiceID)? {
	guard let userID = userID as? ServiceType.UserType.UserIDType else {
		return nil
	}
	return UserAndServiceIDImpl(userID: userID, service: service)
}

public func UserAndServiceIDFrom<ServiceType : UserService>(stringUserID: String, service: ServiceType) throws -> any UserAndServiceID {
	let id = try service.userID(fromString: stringUserID)
	return UserAndServiceIDImpl(userID: id, service: service)
}


/**
 The concrete implementation of the ``UserAndServiceID`` protocol. */
public struct UserAndServiceIDImpl<ServiceType : UserService> : UserAndServiceID {
	
	public var userID: ServiceType.UserType.UserIDType
	public var service: ServiceType
	
	public init(userID: ServiceType.UserType.UserIDType, service: ServiceType) {
		self.userID = userID
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
