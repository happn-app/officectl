/*
 * GroupOfUsersAndService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/26.
 */

import Foundation

import OfficeModelCore

import ServiceKit



/**
 A simple pair of a group of users and its service.
 The pair is hashable, with the tagged id of the user being the hash key, and equatable reference. */
public struct GroupOfUsersAndService<ServiceType : GroupOfUsersService> : Sendable {
	
	public var groupOfUsers: ServiceType.GroupOfUsersType
	public var service: ServiceType
	
	public var taggedID: TaggedID {
		return TaggedID(tag: service.id, id: service.string(fromGroupOfUsersID: groupOfUsers.oGOU_id))
	}
	
	public var taggedPersistentID: TaggedID? {
		return groupOfUsers.oGOU_persistentID.flatMap{ TaggedID(tag: service.id, id: service.string(fromPersistentGroupOfUsersID: $0)) }
	}
	
	public init(groupOfUsers: ServiceType.GroupOfUsersType, service: ServiceType) {
		self.groupOfUsers = groupOfUsers
		self.service = service
	}
	
//	public func hop<NewUserService : GroupOfUsersService>(to newService: NewUserService, hints: [UserProperty: String?] = [:]) throws -> GroupOfUsersAndService<NewUserService> {
//		return try GroupOfUsersAndService<NewUserService>(groupOfUsers: newService., service: newService)
//	}
	
}


extension GroupOfUsersAndService : Hashable {
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.taggedID == rhs.taggedID
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggedID)
	}
	
}
