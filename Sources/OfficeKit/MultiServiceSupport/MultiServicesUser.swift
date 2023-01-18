/*
 * MultiServicesUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import OfficeModelCore

import ServiceKit



public typealias MultiServicesUser = [HashableUserService: Result<(any User)?, Error>]

public extension MultiServicesUser {
	
	/**
	 Tries and fetch the given user from all of the given services.
	 For all of the services, a “logical” user is inferred from the original user and service.
	 If a logical user can be created, it is then fetched as an _existing_ user from the service.
	 If a logical user cannot be created, once we have a fetched other users from other services, we try again with another user and service.
	 In the end, the resulting MultiServicesUser is guaranteed to have one result per service. */
	static func fetch(from userAndService: any UserAndService, in services: Set<HashableUserService>, propertiesToFetch: Set<UserProperty>? = [], using depServices: Services) async throws -> MultiServicesUser {
		var res = [HashableUserService: Result<(any User)?, ErrorCollection>]()
		var triedServiceIDSource = Set<HashableUserService>()
		
		/** The recursive function that fetches the MultiServicesUser. */
		func fetchStep(from source: any UserAndService, in services: Set<HashableUserService>) async -> MultiServicesUser {
			/* First retrieve the users and errors for the given source. */
			let fetchedUsersAndErrors: [HashableUserService: Result<(any User)?, ErrorCollection>] = await withTaskGroup(
				of: (service: HashableUserService, users: Result<(any User)?, Error>).self,
				returning: [HashableUserService: Result<(any User)?, ErrorCollection>].self,
				body: { group in
					for service in services {
						group.addTask{
							let userResult = await Result{ try await source.fetch(in: service.value, propertiesToFetch: propertiesToFetch, using: depServices) }
							return (service, userResult)
						}
					}
					
					var users = [HashableUserService: Result<(any User)?, ErrorCollection>]()
//					for await (service, userResult) in group { /* Crashes w/ Xcode 13.1 (13A1030d) */
					while let (service, userResult) = await group.next() {
						assert(users[service] == nil)
						users[service] = userResult.mapError{ ErrorCollection([$0]) }
					}
					return users
				}
			)
			
			/* Merge the new results (fetchedUsersAndErrors) with our current results (res). */
			res.merge(fetchedUsersAndErrors, uniquingKeysWith: { currentResult, newResult in
				switch (currentResult, newResult) {
					case (.success, .success):
						OfficeKitConfig.logger?.error("Internal error: Got a user fetched twice. current result = \(currentResult), new result = \(newResult)")
						return newResult
						
					case (.success, .failure):
						OfficeKitConfig.logger?.error("Internal error: Got new failure for a result that was successfully fetched. current result = \(currentResult), new result = \(newResult)")
						return currentResult /* We keep the success… */
						
					case (.failure, .success):
						return newResult
						
					case let (.failure(currentFailure), .failure(newFailure)):
						return .failure(ErrorCollection(currentFailure.errors + newFailure.errors))
				}
			})
			
			/* Compute all the service for which we haven’t already successfully fetched a user (or its absence from the service),
			 *  and whose last fetch error was an inability to create a logical user from the source user.
			 * We estimate that if there was a fetch failure for a given service, there is no need to try again. */
			let servicesToFetch = services.filter{ service in
				guard let result = res[service] else {
					OfficeKitConfig.logger?.error("Internal error: Got a service which has no result, that should not be possible. service = \(service)")
					return true
				}
				return (result.failureValue?.errors.last as? Err)?.isCannotInferUserIDFromOtherUser ?? false
			}
			/* Compute all the service for which we have a user that we do not already have tried fetching from. */
			let servicesWithAUser = res.compactMap{
				let (key, value) = $0
				let hasUser: Bool
				switch value {
					case let .success(val): hasUser = (val != nil)
					case .failure:          hasUser = false
				}
				return hasUser ? key : nil
			}
			let servicesToTry = Set(servicesWithAUser).subtracting(triedServiceIDSource)
			
			guard let serviceToTry = servicesToTry.first, servicesToFetch.count > 0 else {
				/* We have finished. Let’s return the results. */
				return res.mapValues{ $0.mapError{ $0 as Error } }
			}
			let userAndServiceToTry = UserAndServiceFrom(user: res[serviceToTry]!.successValue!!, service: serviceToTry.value)!
			
			triedServiceIDSource.insert(serviceToTry)
			return await fetchStep(from: userAndServiceToTry, in: servicesToFetch)
		}
		
		return await fetchStep(from: userAndService, in: services)
	}
	
	static func fetchAll(in services: Set<HashableUserService>, propertiesToFetch: Set<UserProperty>? = nil, includeSuspended: Bool = true, using depServices: Services) async throws -> (users: [MultiServicesUser], fetchErrorsByServices: [HashableUserService: Error]) {
		let (usersAndServices, fetchErrorsByService) = await withTaskGroup(
			of: (service: HashableUserService, users: Result<[any User], Error>).self,
			returning: (usersAndServices: [any UserAndService], fetchErrorsByServices: [HashableUserService: Error]).self,
			body: { group in
				for service in services {
					group.addTask{
						let usersResult = await Result{ try await service.value.listAllUsers(includeSuspended: includeSuspended, propertiesToFetch: propertiesToFetch, using: depServices) }
						return (service, usersResult)
					}
				}
				
				var usersAndServices = [any UserAndService]()
				var fetchErrorsByServices = [HashableUserService: Error]()
				while let (service, usersResult) = await group.next() {
					assert(fetchErrorsByServices[service] == nil)
					assert(!usersAndServices.contains{ $0.service.id == service.value.id })
					switch usersResult {
						case .success(let users): usersAndServices.append(contentsOf: users.map{ UserAndServiceFrom(user: $0, service: service.value)! })
						case .failure(let error): fetchErrorsByServices[service] = error
					}
				}
				return (usersAndServices, fetchErrorsByServices)
			}
		)
		
		let validServices = services.subtracting(fetchErrorsByService.keys)
		return try await (MultiServicesUser.merge(usersAndServices: usersAndServices, validServices: validServices), fetchErrorsByService)
	}
	
	/**
	 Try and merge all the given users in a collection of multi-services users.
	 
	 All the returned users will have a User for all the valid services IDs (the value being `nil` if a linked user was not found for a given user for the given service).
	 If the valid services IDs are set to `nil`, they are inferred from the set of user and services.
	 
	 If the `allowNonValidServices` arg is set to `true`, the returned users might contain a User for a service that has not been declared valid.
	 (The argument is only useful when `validServices` is set to a non-`nil` value.)
	 
	 - Note: The method is async though everything in it is synchronous because the computation can be long and we want not to block everything while the computation is going on.
	 Maybe we should check with absolute certainty the function will actually be called in the bg, but from my limited testing it seems that it should be. */
	static func merge(usersAndServices: [any UserAndService], validServices: Set<HashableUserService>? = nil, allowNonValidServices: Bool = false) async throws -> [MultiServicesUser] {
		/* Transform the input to get something we can use (UserAndService to LinkedUsers + extracting the list of services). */
		let services: Set<HashableUserService>
		let linkedUsersByTaggedID: [TaggedID: LinkedUser]
		do {
			var servicesBuilding = Set<HashableUserService>()
			var linkedUsersByTaggedIDBuilding = [TaggedID: LinkedUser](minimumCapacity: usersAndServices.count)
			for userAndService in usersAndServices {
				let taggedID = userAndService.taggedID
				guard linkedUsersByTaggedIDBuilding[taggedID] == nil else {
					OfficeKitConfig.logger?.warning("UserAndService \(userAndService) found more than once in merge request; ignoring...")
					continue
				}
				linkedUsersByTaggedIDBuilding[taggedID] = LinkedUser(userAndService: userAndService)
				servicesBuilding.insert(.init(userAndService.service))
			}
			linkedUsersByTaggedID = linkedUsersByTaggedIDBuilding
			services = servicesBuilding
		}
		let validServices = validServices ?? services
		
		/* Compute relations between the users. */
		for (_, linkedUser) in linkedUsersByTaggedID {
			for service in services {
				guard let logicallyLinkedTaggedIDs = try? service.value.allLogicalTaggedIDs(fromOtherUser: linkedUser.userAndService.user) else {
//					OfficeKitConfig.logger?.debug("Error finding logically linked user IDs with: {\n  source service ID: \(currentUserServiceID)\n  dest service ID:\(serviceID)\n  source user pair: \(linkedUser.userAndService)\n}")
					continue
				}
				let logicallyLinkedLinkedUsers = logicallyLinkedTaggedIDs.compactMap{ linkedUsersByTaggedID[$0] }
				try logicallyLinkedLinkedUsers.forEach{ try linkedUser.link(to: $0) }
			}
		}
		
		/* Merge the linked users in MultiServicesUsers. */
		var treatedUsersAndServices = Set<TaggedID>()
		return try linkedUsersByTaggedID.compactMap{ kv -> MultiServicesUser? in
			let (taggedID, linkedUser) = kv
			assert(taggedID == linkedUser.userAndService.taggedID)
			
			/* If the current linked user is treated, no need to do it again. */
			guard treatedUsersAndServices.insert(taggedID).inserted else {return nil}
			
			/* Mark other linked users from the same service as treated. */
			treatedUsersAndServices.formUnion(linkedUser.linkedUsersSameService.map(\.userAndService.taggedID))
			
			guard allowNonValidServices || validServices.contains(where: { $0.value.id == taggedID.tag }) else {
				OfficeKitConfig.logger?.info("Not adding UserAndService \(taggedID) in multi-user because it doesn’t have an explicitly-declared-valid service")
				return nil
			}
			
			/* Initial result for the current linked user’s service.
			 * If there is only one user it’s good, we have a success for this service.
			 * If there are other linked users for the same service for this user (e.g. paul@main.domain and paul@alias.domain), we have a failure. */
			var res = [HashableUserService: Result<(any User)?, Error>]()
			if linkedUser.linkedUsersSameService.isEmpty {
				res[.init(linkedUser.userAndService.service)] = .success(linkedUser.userAndService.user)
			} else {
				let users: [any User] = [linkedUser.userAndService.user] + linkedUser.linkedUsersSameService.map{ $0.userAndService.user }
				res[.init(linkedUser.userAndService.service)] = .failure(Err.tooManyUsersFromAPI(users: users))
			}
			
			/* Let’s get all the linked users by services for our current linked user and its linked user for the same service. */
			let allLinkedUsersByServices = ([linkedUser] + linkedUser.linkedUsersSameService).reduce(
				[HashableUserService: Set<LinkedUser>](),
				{ $0.merging($1.linkedUsersByServices, uniquingKeysWith: { $0.union($1) }) }
			)
			for (service, subLinkedUsers) in allLinkedUsersByServices {
				assert(!allLinkedUsersByServices.isEmpty)
				
				let service = service.value
				assert(subLinkedUsers.allSatisfy{ $0.userAndService.serviceID == service.id })
				
				/* When the loop is done, all the linked users will be treated. */
				defer {treatedUsersAndServices.formUnion(subLinkedUsers.map(\.userAndService.taggedID))}
				
				guard let subLinkedUser = subLinkedUsers.onlyElement else {
					/* There are more than one sub-linked user for the current service; we fail. */
					res[service] = .failure(Err.tooManyUsersFromAPI(users: Array(subLinkedUsers.map{ $0.userAndService.user })))
					continue
				}
				
				/* Let’s do an internal logic validation check. */
				guard !treatedUsersAndServices.contains(subLinkedUser.userAndService.taggedID) else {
					throw InternalError(message: "Got already treated linked user! \(subLinkedUser) for \(taggedID)")
				}
				/* And another. */
				guard res[subLinkedUser.userAndService.service] == nil else {
					throw InternalError(message: "Got two linked users for service ID \(subLinkedUser.userAndService.serviceID): \(res[subLinkedUser.userAndService.service]!) and \(subLinkedUser.userAndService)")
				}
				
				/* Finally we’re good! We can set the value of the multi-services user for the given service. */
				res[subLinkedUser.userAndService.service] = .success(subLinkedUser.userAndService.user)
			}
			/* Setting a value for all valid services IDs */
			for s in validServices {
				guard res[s] == nil else {continue}
				res[s] = .success(nil)
			}
			return res
		}
	}
	
}


/**
 This represent a UserAndService, with its linked users by services.
 
 Hashability is done on the represented userAndService; the linked users are ignored. */
private class LinkedUser : Hashable, CustomStringConvertible {
	
	let userAndService: any UserAndService
	
	var linkedUsersSameService = Set<LinkedUser>()
	var linkedUsersByServices: [HashableUserService: Set<LinkedUser>] = [:]
	
	var description: String {
		return "LinkedUser<\(userAndService.taggedID)>; linkedUsersSameService: \(linkedUsersSameService.map{ $0.userAndService.taggedID }); linkedUsers: \(linkedUsersByServices.values.flatMap{ $0 }.map{ $0.userAndService.taggedID })"
	}
	
	static func ==(lhs: LinkedUser, rhs: LinkedUser) -> Bool {
		return lhs.userAndService.taggedID == rhs.userAndService.taggedID
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(userAndService.taggedID)
	}
	
	init(userAndService: any UserAndService) {
		self.userAndService = userAndService
	}
	
	subscript<Service : UserService>(_ service: Service) -> Set<LinkedUser> {
		get {
			if service.id == userAndService.serviceID {return linkedUsersSameService}
			else                                      {return linkedUsersByServices[HashableUserService(service), default: []]}
		}
		set {
			if service.id == userAndService.serviceID {linkedUsersSameService = newValue}
			else                                      {linkedUsersByServices[HashableUserService(service)] = newValue}
		}
	}
	
	func link(to linkedUser: LinkedUser) throws {
		var visited = Set<[TaggedID]>()
		return try link(to: linkedUser, visited: &visited)
	}
	
	private func link(to linkedUser: LinkedUser, visited: inout Set<[TaggedID]>) throws {
		guard visited.insert([userAndService.taggedID, linkedUser.userAndService.taggedID]).inserted else {
			return
		}
		
		if userAndService.taggedID != linkedUser.userAndService.taggedID {
			/* Make the actual link. */
			self[linkedUser.userAndService.service].insert(linkedUser)
			/* Make the reverse link. */
			try linkedUser.link(to: self, visited: &visited)
		}
		/* Link related users. */
		for toLink in (linkedUsersByServices.values.flatMap{ $0 }) {
			assert(toLink.linkedUsersByServices.values.flatMap{ $0 }.contains(where: { $0.userAndService.taggedID == userAndService.taggedID }))
			try toLink.link(to: linkedUser, visited: &visited)
		}
	}
	
}


private struct InternalError : Error {
	
	var message: String
	
}
