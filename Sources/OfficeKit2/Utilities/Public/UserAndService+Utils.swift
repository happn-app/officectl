/*
 * UserService+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/26.
 */

import Foundation

import Email
import OfficeModelCore

import ServiceKit



public extension UserAndService {
	
	var taggedID: TaggedID {
		return TaggedID(tag: service.id, id: service.string(fromUserID: user.id))
	}
	
	var taggedPersistentID: TaggedID? {
		return user.persistentID.flatMap{ TaggedID(tag: service.id, id: service.string(fromPersistentUserID: $0)) }
	}
	
	var wrappedUser: UserWrapper {
		get throws {
			var ret = UserWrapper(
				id: taggedID,
				persistentID: taggedPersistentID,
				underlyingUser: try service.json(fromUser: user)
			)
			ret.copyStandardNonIDProperties(fromUser: user)
			return ret
		}
	}
	
	func logicalID<OtherServiceType : UserService>(in otherService: OtherServiceType) throws -> OtherServiceType.UserType.IDType {
		return try otherService.logicalUser(fromWrappedUser: wrappedUser).id
	}
	
	func fetch<OtherServiceType : UserService>(in otherService: OtherServiceType, propertiesToFetch: Set<UserProperty> = [], using depServices: Services) async throws -> OtherServiceType.UserType? {
		let otherID = try logicalID(in: otherService)
		return try await otherService.existingUser(fromUserID: otherID, propertiesToFetch: propertiesToFetch, using: depServices)
	}
	
}
