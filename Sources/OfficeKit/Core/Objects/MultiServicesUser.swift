/*
 * MultiServicesUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/08/2019.
 */

import Foundation

import NIO
import ServiceKit



public typealias MultiServicesUser = MultiServicesItem<AnyDSUPair?>
extension MultiServicesUser {
	
	public static func fetch(from dsuIdPair: AnyDSUIdPair, in services: Set<AnyUserDirectoryService>, using depServices: Services) async throws -> MultiServicesUser {
		return try await fetch(from: dsuIdPair.dsuPair(), in: services, using: depServices)
	}
	
	public static func fetch(from dsuPair: AnyDSUPair, in services: Set<AnyUserDirectoryService>, using depServices: Services) async -> MultiServicesUser {
		#warning("TODO: Properties to fetch")
		var allFetchedUsers = [AnyUserDirectoryService: AnyDSUPair?]()
		var allFetchedErrors = [AnyUserDirectoryService: [Error]]()
		var triedServiceIdSource = Set<AnyUserDirectoryService>()
		
		func getUsers(from dsuPair: AnyDSUPair, in services: Set<AnyUserDirectoryService>) async -> [AnyUserDirectoryService: Result<AnyDSUPair?, Error>] {
			return await withTaskGroup(
				of: (service: AnyUserDirectoryService, users: Result<AnyDirectoryUser?, Error>).self,
				returning: [AnyUserDirectoryService: Result<AnyDSUPair?, Error>].self,
				body: { group in
					for service in services {
						group.addTask{
							let userResult = await Result{ try await service.existingUser(fromUser: dsuPair.user, in: dsuPair.service, propertiesToFetch: [], using: depServices) }
							return (service, userResult)
						}
					}
					
					var users = [AnyUserDirectoryService: Result<AnyDSUPair?, Error>]()
//					for await (service, userResult) in group { /* Crashes w/ Xcode 13.1 (13A1030d) */
					while let (service, userResult) = await group.next() {
						assert(users[service] == nil)
						users[service] = userResult.map{ curUser in curUser.flatMap{ curUser -> AnyDSUPair in AnyDSUPair(service: service, user: curUser) } }
					}
					return users
				}
			)
		}
		
		func fetchStep(fetchedUsersAndErrors: [AnyUserDirectoryService: Result<AnyDSUPair?, Error>]) async -> MultiServicesUser {
			/* Try and fetch the users that were not successfully fetched. */
			allFetchedUsers = allFetchedUsers.merging(fetchedUsersAndErrors.compactMapValues{ $0.successValue }, uniquingKeysWith: { old, new in
				OfficeKitConfig.logger?.error("Got a user fetched twice for id \(String(describing: old?.user.userId ?? new?.user.userId)). old user = \(String(describing: old)), new user = \(String(describing: new))")
				return new
			})
			allFetchedErrors = allFetchedErrors.merging(fetchedUsersAndErrors.compactMapValues{ $0.failureValue.flatMap{ [$0] } }, uniquingKeysWith: { old, new in old + new })
			
			#warning("TODO: Only try and re-fetched users whose fetch error was a “I don’t have enough info to fetch” error.")
			/* Line below: All the service ids for which we haven’t already successfully fetched a user (or its absence from the service). */
			let servicesToFetch = services.filter{ !allFetchedUsers.keys.contains($0) }
			/* Line below: All the service ids for which we have a user that we do not already have tried fetching from. */
			let serviceIdsToTry = Set(allFetchedUsers.compactMap{ $0.value != nil ? $0.key : nil }).subtracting(triedServiceIdSource)
			
			guard let serviceIdToTry = serviceIdsToTry.first, servicesToFetch.count > 0 else {
				/* We have finished. Let’s return the results. */
				return MultiServicesUser(itemsByService: allFetchedUsers, errorsByService: allFetchedErrors.mapValues{ ErrorCollection($0) })
			}
			
			triedServiceIdSource.insert(serviceIdToTry)
			return await fetchStep(fetchedUsersAndErrors: getUsers(from: allFetchedUsers[serviceIdToTry]!!, in: servicesToFetch))
		}
		
		return await fetchStep(fetchedUsersAndErrors: getUsers(from: dsuPair, in: services))
	}
	
	public static func fetchAll(in services: Set<AnyUserDirectoryService>, using depServices: Services) async throws -> (users: [MultiServicesUser], fetchErrorsByServices: [AnyUserDirectoryService: Error]) {
		let eventLoop = try depServices.eventLoop()
		let (pairs, fetchErrorsByService) = await AnyDSUPair.fetchAll(in: services, using: depServices)
		let validServices = services.subtracting(fetchErrorsByService.keys)
		return try await MultiServicesUser.merge(dsuPairs: Set(pairs), validServices: validServices, eventLoop: eventLoop).map{ ($0, fetchErrorsByService) }.get()
	}
	
	/**
	Try and merge all the given users in a collection of multi-services users.
	
	All the returned users will have a DSU pair for all the valid services ids
	(the value being `nil` if a linked user was not found for a given user for
	the given service). If the valid services ids are set to `nil`, they are
	inferred from the set of DSU pairs.
	
	If the `allowNonValidServices` arg is set to `true`, the returned users might
	contain a DSU pair for a service that has not been declared valid. (The
	argument is only useful when `validServices` is set to a non-`nil` value.) */
	public static func merge(dsuPairs: Set<AnyDSUPair>, validServices: Set<AnyUserDirectoryService>? = nil, allowNonValidServices: Bool = false, eventLoop: EventLoop, dispatchQueue: DispatchQueue = defaultDispatchQueueForFutureSupport) -> EventLoopFuture<[MultiServicesUser]> {
		let promise = eventLoop.makePromise(of: [MultiServicesUser].self)
		dispatchQueue.async{
			do {
				/* Transform the input to get something we can use (DSUPairs to LinkedUsers + extracting the list of services). */
				let services: Set<AnyUserDirectoryService>
				let linkedUsersByDSUPair: [AnyDSUPair: LinkedUser]
				do {
					var servicesBuilding = Set<AnyUserDirectoryService>()
					var linkedUsersByDSUPairBuilding = [AnyDSUPair: LinkedUser](minimumCapacity: dsuPairs.count)
					for pair in dsuPairs {
						assert(linkedUsersByDSUPairBuilding[pair] == nil)
						linkedUsersByDSUPairBuilding[pair] = LinkedUser(dsuPair: pair)
						servicesBuilding.insert(pair.service)
					}
					linkedUsersByDSUPair = linkedUsersByDSUPairBuilding
					services = servicesBuilding
				}
				let validServices = validServices ?? services
				
				/* Compute relations between the users. */
				for (_, linkedUser) in linkedUsersByDSUPair {
					let currentUserServiceId = linkedUser.dsuPair.serviceId
					for service in services {
						let serviceId = service.config.serviceId
						guard serviceId != currentUserServiceId else {continue}
						guard let logicallyLinkedPair = try? linkedUser.dsuPair.hop(to: service) else {
//							OfficeKitConfig.logger?.debug("Error finding logically linked user with: {\n  source service id: \(currentUserServiceId)\n  dest service id:\(serviceId)\n  source user pair: \(linkedUser.dsuPair)\n}")
							continue
						}
						guard let logicallyLinkedLinkedUser = linkedUsersByDSUPair[logicallyLinkedPair] else {
//							OfficeKitConfig.logger?.debug("Found logically linked user, but user does not exist: {\n  source service id: \(currentUserServiceId)\n  dest service id:\(serviceId)\n  source user pair: \(linkedUser.dsuPair)\n  dest user pair: \(logicallyLinkedPair.dsuIdPair)\n}")
							continue
						}
						try linkedUser.link(to: logicallyLinkedLinkedUser)
					}
				}
				
				/* Merge the linked users in MultiServicesUsers. */
				var treatedDSUPairs = Set<AnyDSUPair>()
				let results = try linkedUsersByDSUPair.compactMap{ kv -> MultiServicesUser? in
					let (dsuPair, linkedUser) = kv
					
					guard !treatedDSUPairs.contains(dsuPair) else {return nil}
					treatedDSUPairs.insert(dsuPair)
					
					guard allowNonValidServices || validServices.contains(dsuPair.service) else {
						OfficeKitConfig.logger?.info("Not adding DSU pair \(dsuPair) in multi-user because it doesn’t have an explicitly-declared-valid service")
						return nil
					}
					
					var res: [AnyUserDirectoryService: AnyDSUPair?] = [linkedUser.dsuPair.service: linkedUser.dsuPair]
					for subLinkedUser in linkedUser.linkedUserByServiceId.values {
						guard !treatedDSUPairs.contains(subLinkedUser.dsuPair) else {
							throw InternalError(message: "Got already treated linked user! \(subLinkedUser.dsuPair) for \(dsuPair)")
						}
						guard res[subLinkedUser.dsuPair.service] == nil else {
							throw InternalError(message: "Got two users for service id \(subLinkedUser.dsuPair.service): \(res[subLinkedUser.dsuPair.service]!!) and \(subLinkedUser.dsuPair)")
						}
						res[subLinkedUser.dsuPair.service] = subLinkedUser.dsuPair
						treatedDSUPairs.insert(subLinkedUser.dsuPair)
					}
					/* Setting a value for all valid services ids */
					for s in validServices {
						guard res[s] == nil else {continue}
						res[s] = .some(nil)
					}
					return MultiServicesUser(itemsByService: res)
				}
				
				promise.succeed(results)
			} catch {
				promise.fail(error)
			}
		}
		return promise.futureResult
	}
	
}


private class LinkedUser : CustomStringConvertible {
	
	let dsuPair: AnyDSUPair
	var linkedUserByServiceId: [AnyUserDirectoryService: LinkedUser] = [:]
	
	var description: String {
		return "LinkedUser<\("service.config.serviceId") - \("user")>; linkedUsers: \("linkedUserByServiceId.keys")"
	}
	
	init(dsuPair p: AnyDSUPair) {
		dsuPair = p
	}
	
	func link(to linkedUser: LinkedUser) throws {
		var visited = Set<[AnyDSUPair]>()
		return try link(to: linkedUser, visited: &visited)
	}
	
	private func link(to linkedUser: LinkedUser, visited: inout Set<[AnyDSUPair]>) throws {
		guard !visited.contains([dsuPair, linkedUser.dsuPair]) else {return}
		visited.insert([dsuPair, linkedUser.dsuPair])
		
		guard dsuPair != linkedUser.dsuPair else {
			/* Not linking myself to myself… */
			return
		}
		
		/* Make the actual link. */
		if let currentlyLinkedUser = linkedUserByServiceId[linkedUser.dsuPair.service] {
			guard currentlyLinkedUser.dsuPair == linkedUser.dsuPair else {
				throw InvalidArgumentError(message: "DSUPair \(dsuPair) is asked to be linked to \(linkedUser.dsuPair), but is also already linked to \(currentlyLinkedUser.dsuPair)")
			}
		} else {
			linkedUserByServiceId[linkedUser.dsuPair.service] = linkedUser
		}
		/* Make the reverse link. */
		try linkedUser.link(to: self, visited: &visited)
		/* Link related users. */
		for toLink in linkedUserByServiceId.values {
			assert(toLink.linkedUserByServiceId.values.contains(where: { $0.dsuPair == dsuPair }))
			try toLink.link(to: linkedUser, visited: &visited)
		}
	}
	
}
