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
		return service.taggedID(fromUserID: user.id)
	}
	
	public var taggedPersistentID: TaggedID? {
		return user.persistentID.flatMap(service.taggedID(fromPersistentUserID:))
	}
	
	public init(user: ServiceType.UserType, service: ServiceType) {
		self.user = user
		self.service = service
	}
	
	/* Does not seem to work, sadly. */
//	public init?<UserType : User>(anyUser: UserType, service: ServiceType) {
//		guard let user = anyUser as? ServiceType.UserType else {
//			return nil
//		}
//		self.user = user
//		self.service = service
//	}
	
}


extension UserAndService : Hashable {
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.taggedID == rhs.taggedID
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggedID)
	}
	
}
