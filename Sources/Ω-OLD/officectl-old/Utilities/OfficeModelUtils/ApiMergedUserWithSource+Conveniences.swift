/*
 * ApiMergedUserWithSource+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/30.
 */

import Foundation

import Email

import OfficeKit
import OfficeModel



extension ApiMergedUserWithSource {
	
	init(multiUsers: MultiServicesUser, orderedServices: [AnyUserDirectoryService]) throws {
		try self.init(usersByService: multiUsers.itemsByService.compactMapValues{ try $0?.userWrapper() }, orderedServices: orderedServices)
	}
	
	init(usersByService users: [AnyUserDirectoryService: DirectoryUserWrapper], orderedServices: [AnyUserDirectoryService]) {
		let orderedAndUniquedServices = Self.addMissingElements(from: orderedServices + Array(users.keys), to: [])
		let sortedUserWrappers = orderedAndUniquedServices.compactMap{ users[$0] }
		assert(sortedUserWrappers.count == users.count)
		
		let emails: [Email]? = sortedUserWrappers.reduce(nil, { currentEmails, user in
			return Self.addMissingElements(from: user.emails, to: currentEmails ?? [])
		})
		let firstName = sortedUserWrappers.lazy.compactMap{ $0.firstName }.first ?? nil
		let lastName  = sortedUserWrappers.lazy.compactMap{ $0.lastName  }.first ?? nil
		let nickname  = sortedUserWrappers.lazy.compactMap{ $0.nickname  }.first ?? nil
		self.init(
			emails: emails,
			firstName: firstName,
			lastName:  lastName,
			nickname:  nickname,
			directoryUsers: users.mapKeys{ $0.config.serviceID }.mapValues{ ApiDirectoryUser(directoryUserWrapper: $0) }
		)
	}
	
	/* Shame OrderedSet does not exist in Swift… Will not add a dependency just for that though. */
	private static func addMissingElements<E : Hashable>(from addedElements: [E], to collection: [E]) -> [E] {
		var res = collection
		for e in addedElements {
			if !res.contains(e) {
				res.append(e)
			}
		}
		return res
	}
	
}
