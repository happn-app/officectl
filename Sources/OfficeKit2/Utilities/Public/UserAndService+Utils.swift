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
	
	var serviceID: String {
		return service.id
	}
	
	var taggedID: TaggedID {
		return TaggedID(tag: service.id, id: service.string(fromUserID: user.oU_id))
	}
	
	var taggedPersistentID: TaggedID? {
		return user.oU_persistentID.flatMap{ TaggedID(tag: service.id, id: service.string(fromPersistentUserID: $0)) }
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
	
	func fetch<OtherServiceType : UserService>(in otherService: OtherServiceType, propertiesToFetch: Set<UserProperty> = [], using depServices: Services) async throws -> OtherServiceType.UserType? {
		let otherID = try otherService.logicalUser(fromWrappedUser: wrappedUser).oU_id
		return try await otherService.existingUser(fromUserID: otherID, propertiesToFetch: propertiesToFetch, using: depServices)
	}
	
}
