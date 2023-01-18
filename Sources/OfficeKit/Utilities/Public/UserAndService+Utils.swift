/*
 * UserService+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/26.
 */

import Foundation

import CollectionConcurrencyKit
import Email
import GenericJSON
import Logging
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
	
	var shortUserDescription: String {
		return service.shortDescription(fromUser: user)
	}
	
	func fetch<OtherServiceType : UserService>(in otherService: OtherServiceType, propertiesToFetch: Set<UserProperty>? = [], using depServices: Services) async throws -> OtherServiceType.UserType? {
		let otherID = try otherService.logicalUserID(fromUser: user)
		return try await otherService.existingUser(fromID: otherID, propertiesToFetch: propertiesToFetch, using: depServices)
	}
	
}
