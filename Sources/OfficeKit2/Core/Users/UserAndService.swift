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
 A simple pair of a user and its service.
 The pair is hashable, with the tagged id of the user being the hash key, and equatable reference. */
public struct UserAndService<ServiceType : UserService> : Sendable {
	
	public var user: ServiceType.UserType
	public var service: ServiceType
	
	public var taggedID: TaggedID {
		return TaggedID(tag: service.id, id: service.string(fromUserID: user.id))
	}
	
	public var taggedPersistentID: TaggedID? {
		return user.persistentID.flatMap{ TaggedID(tag: service.id, id: service.string(fromPersistentUserID: $0)) }
	}
	
	public init(user: ServiceType.UserType, service: ServiceType) {
		self.user = user
		self.service = service
	}
	
	public func hop<NewUserService : UserService>(to newService: NewUserService, hints: [UserProperty: String?] = [:]) throws -> UserAndService<NewUserService> {
		return try UserAndService<NewUserService>(user: newService.logicalUser(fromUser: user, in: service, hints: hints), service: newService)
	}
	
}


extension UserAndService : Hashable {
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.taggedID == rhs.taggedID
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggedID)
	}
	
}
