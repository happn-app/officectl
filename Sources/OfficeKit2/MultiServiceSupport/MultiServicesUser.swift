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
				return (result.failureValue?.errors.last as? Err)?.isCannotCreateLogicalUserFromOtherUser ?? false
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
	 Maybe we should check with absolute certainty the function will actually be called in the bg, but from my limited testing it seems it should be. */
	static func merge(usersAndServices: [any UserAndService], validServices: Set<HashableUserService>? = nil, allowNonValidServices: Bool = false) async throws -> [MultiServicesUser] {
		/* Transform the input to get something we can use (UserAndService to LinkedUsers + extracting the list of services). */
		let services: Set<HashableUserService>
		let linkedUsersByUserAndService: [HashableUserAndService: LinkedUser]
		do {
			var servicesBuilding = Set<HashableUserService>()
			var linkedUsersByUserAndServiceBuilding = [HashableUserAndService: LinkedUser](minimumCapacity: usersAndServices.count)
			for userAndService in usersAndServices {
				let hashableUserAndService = HashableUserAndService(userAndService)
				guard linkedUsersByUserAndServiceBuilding[hashableUserAndService] == nil else {
					OfficeKitConfig.logger?.warning("UserAndService \(userAndService) found more than once in merge request; ignoring...")
					continue
				}
				linkedUsersByUserAndServiceBuilding[hashableUserAndService] = LinkedUser(userAndService: userAndService)
				servicesBuilding.insert(.init(userAndService.service))
			}
			linkedUsersByUserAndService = linkedUsersByUserAndServiceBuilding
			services = servicesBuilding
		}
		let validServices = validServices ?? services
		
		/* Compute relations between the users. */
		for (_, linkedUser) in linkedUsersByUserAndService {
			let currentUserServiceID = linkedUser.userAndService.serviceID
			for service in services {
				let serviceID = service.value.id
				guard serviceID != currentUserServiceID else {continue}
				guard let logicallyLinkedPair = try? UserAndServiceFrom(user: service.value.logicalUser(fromUser: linkedUser.userAndService.user), service: service.value)! else {
//					OfficeKitConfig.logger?.debug("Error finding logically linked user with: {\n  source service ID: \(currentUserServiceID)\n  dest service ID:\(serviceID)\n  source user pair: \(linkedUser.userAndService)\n}")
					continue
				}
				guard let logicallyLinkedLinkedUser = linkedUsersByUserAndService[.init(logicallyLinkedPair)] else {
//					OfficeKitConfig.logger?.debug("Found logically linked user, but user does not exist: {\n  source service ID: \(currentUserServiceID)\n  dest service ID:\(serviceID)\n  source user pair: \(linkedUser.userAndService)\n  dest user pair: \(logicallyLinkedPair.dsuIDPair)\n}")
					continue
				}
				try linkedUser.link(to: logicallyLinkedLinkedUser)
			}
		}
		
		/* Merge the linked users in MultiServicesUsers. */
		var treatedUsersAndServices = Set<TaggedID>()
		return try linkedUsersByUserAndService.compactMap{ kv -> MultiServicesUser? in
			let (userAndService, linkedUser) = kv
			
			guard treatedUsersAndServices.insert(userAndService.value.taggedID).inserted else {return nil}
			
			guard allowNonValidServices || validServices.contains(.init(userAndService.value.service)) else {
				OfficeKitConfig.logger?.info("Not adding UserAndService \(userAndService) in multi-user because it doesn’t have an explicitly-declared-valid service")
				return nil
			}
			
			var res: [HashableUserService: (any User)?] = [.init(linkedUser.userAndService.service): linkedUser.userAndService.user]
			for subLinkedUser in linkedUser.linkedUserByService.values {
				guard !treatedUsersAndServices.contains(subLinkedUser.userAndService.taggedID) else {
					throw InternalError(message: "Got already treated linked user! \(subLinkedUser.userAndService) for \(userAndService)")
				}
				guard res[subLinkedUser.userAndService.service] == nil else {
					throw InternalError(message: "Got two users for service ID \(subLinkedUser.userAndService.serviceID): \(res[subLinkedUser.userAndService.service]!!) and \(subLinkedUser.userAndService)")
				}
				res[subLinkedUser.userAndService.service] = subLinkedUser.userAndService.user
				treatedUsersAndServices.insert(subLinkedUser.userAndService.taggedID)
			}
			/* Setting a value for all valid services IDs */
			for s in validServices {
				guard res[s] == nil else {continue}
				res[s] = .some(nil)
			}
			return res.mapValues{ .success($0) }
		}
	}
	
}


private class LinkedUser : CustomStringConvertible {
	
	let userAndService: any UserAndService
	var linkedUserByService: [HashableUserService: LinkedUser] = [:]
	
	var description: String {
		return "LinkedUser<\("service.config.serviceID") - \("user")>; linkedUsers: \("linkedUserByServiceID.keys")"
	}
	
	init(userAndService: any UserAndService) {
		self.userAndService = userAndService
	}
	
	func link(to linkedUser: LinkedUser) throws {
		var visited = Set<[TaggedID]>()
		return try link(to: linkedUser, visited: &visited)
	}
	
	private func link(to linkedUser: LinkedUser, visited: inout Set<[TaggedID]>) throws {
		guard visited.insert([userAndService.taggedID, linkedUser.userAndService.taggedID]).inserted else {return}
		
		guard userAndService.taggedID != linkedUser.userAndService.taggedID else {
			/* Not linking myself to myself… */
			return
		}
		
		/* Make the actual link. */
		if let currentlyLinkedUser = linkedUserByService[linkedUser.userAndService.service] {
			guard currentlyLinkedUser.userAndService.taggedID == linkedUser.userAndService.taggedID else {
				throw InternalError(message: "UserAndService \(userAndService) is asked to be linked to \(linkedUser.userAndService), but is also already linked to \(currentlyLinkedUser.userAndService)")
			}
		} else {
			linkedUserByService[linkedUser.userAndService.service] = linkedUser
		}
		/* Make the reverse link. */
		try linkedUser.link(to: self, visited: &visited)
		/* Link related users. */
		for toLink in linkedUserByService.values {
			assert(toLink.linkedUserByService.values.contains(where: { $0.userAndService.taggedID == userAndService.taggedID }))
			try toLink.link(to: linkedUser, visited: &visited)
		}
	}
	
}


private struct InternalError : Error {
	
	var message: String
	
}
