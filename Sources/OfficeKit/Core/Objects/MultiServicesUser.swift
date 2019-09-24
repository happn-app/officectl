/*
 * MultiServicesUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/08/2019.
 */

import Foundation

import NIO
import Service



public typealias MultiServicesUser = MultiServicesItem<AnyDSUPair?>
extension MultiServicesUser {
	
	public static func fetch(from dsuIdPair: AnyDSUIdPair, in services: Set<AnyUserDirectoryService>, on container: Container) throws -> EventLoopFuture<MultiServicesUser> {
		#warning("TODO: Properties to fetch")
		let servicesById = try services.group(by: { $0.config.serviceId })
		
		var allFetchedUsers = [AnyUserDirectoryService: AnyDSUPair?]()
		var allFetchedErrors = [AnyUserDirectoryService: [Error]]()
		var triedServiceIdSource = Set<AnyUserDirectoryService>()
		
		func getUsers(from dsuPair: AnyDSUPair, in services: Set<AnyUserDirectoryService>) -> EventLoopFuture<[AnyUserDirectoryService: Result<AnyDSUPair?, Error>]> {
			let userFutures = services.map{ curService in
				(curService, container.future().flatMap{
					try curService.existingUser(fromUser: dsuPair.user, in: dsuPair.service, propertiesToFetch: [], on: container)
				})
			}
			return Future.waitAll(userFutures, eventLoop: container.eventLoop).map{ userResults in
				return try userResults.group(
					by:            { $0.0 },
					mappingValues: {
						let (service, userOrError) = $0
						return userOrError.map{ curUser in curUser.flatMap{ curUser -> AnyDSUPair in AnyDSUPair(service: service, user: curUser) } }
					}
				)
			}
		}
		
		func fetchStep(fetchedUsersAndErrors: [AnyUserDirectoryService: Result<AnyDSUPair?, Error>]) throws -> EventLoopFuture<MultiServicesUser> {
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
				let multiServicesUser = MultiServicesUser(itemsByService: allFetchedUsers, errorsByService: allFetchedErrors.mapValues{ ErrorCollection($0) })
				return container.eventLoop.newSucceededFuture(result: multiServicesUser)
			}
			
			triedServiceIdSource.insert(serviceIdToTry)
			return getUsers(from: allFetchedUsers[serviceIdToTry]!!, in: servicesToFetch).flatMap(fetchStep)
		}
		
		return try getUsers(from: dsuIdPair.dsuPair(), in: services).flatMap(fetchStep)
	}
	
	public static func fetchAll(in services: Set<AnyUserDirectoryService>, on container: Container) throws -> EventLoopFuture<(users: [MultiServicesUser], fetchErrorsByServices: [AnyUserDirectoryService: Error])> {
		return try AnyDSUPair.fetchAll(in: services, on: container).flatMap{
			let (pairs, fetchErrorsByService) = $0
			let validServices = services.subtracting(fetchErrorsByService.keys)
			return MultiServicesUser.merge(dsuPairs: Set(pairs), validServices: validServices, eventLoop: container.eventLoop).map{ ($0, fetchErrorsByService) }
		}
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
		let promise = eventLoop.newPromise([MultiServicesUser].self)
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
				
				promise.succeed(result: results)
			} catch {
				promise.fail(error: error)
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
