/*
 * ApiUser.swift
 * officectl
 *
 * Created by François Lamboley on 15/08/2019.
 */

import Foundation

import GenericJSON
import OfficeKit



struct ApiUser : Encodable {
	
	var emails: [Email]?
	
	var firstName: String?
	var lastName: String?
	var nickname: String?
	
	var usersByServiceId: [String: DirectoryUserWrapper?]
	
	init(multiUsers: MultiServicesUser, orderedServices: [AnyDirectoryService]) throws {
		#warning("TODO: Note that we ignore the errors by service ids. Is this what we really want?")
		try self.init(usersByService: multiUsers.itemsByService.mapValues{ try $0?.userWrapper() }, orderedServices: orderedServices)
	}
	
	init(usersByService users: [AnyDirectoryService: DirectoryUserWrapper?], orderedServices: [AnyDirectoryService]) {
		usersByServiceId = users.mapKeys{ $0.config.serviceId }
		
		let orderedAndUniquedServices = ApiUser.addMissingElements(from: orderedServices + Array(users.keys), to: [])
		let sortedUserWrappers = orderedAndUniquedServices.compactMap{ users[$0] }
		assert(sortedUserWrappers.count == users.count)
		
		emails = sortedUserWrappers.reduce(nil, { currentEmails, user in
			guard let newEmails = user?.emails.value else {return currentEmails}
			return ApiUser.addMissingElements(from: newEmails, to: currentEmails ?? [])
		})
		
		firstName = sortedUserWrappers.lazy.compactMap{ $0?.firstName.value }.first ?? nil
		lastName  = sortedUserWrappers.lazy.compactMap{ $0?.lastName.value  }.first ?? nil
		nickname  = sortedUserWrappers.lazy.compactMap{ $0?.nickname.value  }.first ?? nil
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
