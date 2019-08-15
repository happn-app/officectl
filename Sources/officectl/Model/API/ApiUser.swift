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
	
	var underlyingUsersByServiceId: [String: JSON?]
	
	init(users: [String: DirectoryUserWrapper?], orderedServicesIds: [String]) {
		underlyingUsersByServiceId = users.mapValues{ $0?.underlyingUser }
		
		let orderedAndUniquedServicesIds = ApiUser.addMissingElements(from: Array(users.keys), to: ApiUser.addMissingElements(from: orderedServicesIds, to: []))
		let sortedUsers = orderedAndUniquedServicesIds.compactMap{ users[$0] }
		assert(sortedUsers.count == users.count)
		
		emails = sortedUsers.reduce(nil, { currentEmails, user in
			guard let newEmails = user?.emails.value else {return currentEmails}
			return ApiUser.addMissingElements(from: newEmails, to: currentEmails ?? [])
		})
		
		firstName = sortedUsers.compactMap{ $0?.firstName.value }.first ?? nil
		lastName  = sortedUsers.compactMap{ $0?.lastName.value  }.first ?? nil
		nickname  = sortedUsers.compactMap{ $0?.nickname.value  }.first ?? nil
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
