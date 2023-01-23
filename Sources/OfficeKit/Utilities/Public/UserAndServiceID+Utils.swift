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



public extension UserAndServiceID {
	
	var serviceID: Tag {
		return service.id
	}
	
	var taggedID: TaggedID {
		return TaggedID(tag: service.id, id: service.string(fromUserID: userID))
	}
	
	func fetch(propertiesToFetch: Set<UserProperty>? = [], using depServices: Services) async throws -> (any UserAndService)? {
		guard let user = try await service.existingUser(fromID: userID, propertiesToFetch: propertiesToFetch, using: depServices) else {
			return nil
		}
		return UserAndServiceFrom(user: user, service: service)
	}
	
}
