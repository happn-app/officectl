/*
 * MultiServicesUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 19/08/2019.
 */

import Foundation

import NIO
import Service



internal class LinkedUser : CustomStringConvertible {
	
	let dsuPair: AnyDSUPair
	var linkedUserByServiceId: [String: LinkedUser] = [:]
	
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
		if let currentlyLinkedUser = linkedUserByServiceId[linkedUser.dsuPair.serviceId] {
			guard currentlyLinkedUser.dsuPair == linkedUser.dsuPair else {
				throw InvalidArgumentError(message: "DSUPair \(dsuPair) is asked to be linked to \(linkedUser.dsuPair), but is also already linked to \(currentlyLinkedUser.dsuPair)")
			}
		} else {
			linkedUserByServiceId[linkedUser.dsuPair.serviceId] = linkedUser
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


public struct MultiServicesUser {
	
	public static func fetch(from dsuIdPair: AnyDSUIdPair, in services: [AnyDirectoryService], on container: Container) throws -> EventLoopFuture<MultiServicesUser> {
		#warning("TODO: Properties to fetch")
		let servicesById = try services.group(by: { $0.config.serviceId })
		
		var allFetchedUsers = [String: AnyDSUPair?]()
		var allFetchedErrors = [String: [Error]]()
		var triedServiceIdSource = Set<String>()
		
		func getUsers(from dsuPair: AnyDSUPair, in services: [AnyDirectoryService]) -> EventLoopFuture<[String: Result<AnyDSUPair?, Error>]> {
			let userFutures = services.map{ curService in
				container.future().flatMap{
					try curService.existingUser(fromUser: dsuPair.user, in: dsuPair.service, propertiesToFetch: [], on: container)
				}
			}
			return Future.waitAll(userFutures, eventLoop: container.eventLoop).map{ userResults in
				var res = [String: Result<AnyDSUPair?, Error>]()
				for (idx, userResult) in userResults.enumerated() {
					let service = services[idx]
					res[service.config.serviceId] = userResult.map{ curUser in curUser.flatMap{ curUser -> AnyDSUPair in AnyDSUPair(service: service, user: curUser) } }
				}
				return res
			}
		}
		
		func fetchStep(fetchedUsersAndErrors: [String: Result<AnyDSUPair?, Error>]) throws -> EventLoopFuture<MultiServicesUser> {
			/* Try and fetch the users that were not successfully fetched. */
			allFetchedUsers = allFetchedUsers.merging(fetchedUsersAndErrors.compactMapValues{ $0.successValue }, uniquingKeysWith: { old, new in
				OfficeKitConfig.logger?.error("Got a user fetched twice for id \(String(describing: old?.user.userId ?? new?.user.userId)). old user = \(String(describing: old)), new user = \(String(describing: new))")
				return new
			})
			allFetchedErrors = allFetchedErrors.merging(fetchedUsersAndErrors.compactMapValues{ $0.failureValue.flatMap{ [$0] } }, uniquingKeysWith: { old, new in old + new })
			
			#warning("TODO: Only try and re-fetched users whose fetch error was a “I don’t have enough info to fetch” error.")
			/* Line below: All the service ids for which we haven’t already successfully fetched a user (or its absence from the service). */
			let servicesToFetch = services.filter{ !allFetchedUsers.keys.contains($0.config.serviceId) }
			/* Line below: All the service ids for which we have a user that we do not already have tried fetching from. */
			let serviceIdsToTry = Set(allFetchedUsers.compactMap{ $0.value != nil ? $0.key : nil }).subtracting(triedServiceIdSource)
			
			guard let serviceIdToTry = serviceIdsToTry.first, servicesToFetch.count > 0 else {
				/* We have finished. Let’s return the results. */
				let multiServicesUser = MultiServicesUser(pairsByServiceId: allFetchedUsers, errorsByServiceId: allFetchedErrors.mapValues{ ErrorCollection($0) })
				return container.eventLoop.newSucceededFuture(result: multiServicesUser)
			}
			
			triedServiceIdSource.insert(serviceIdToTry)
			return getUsers(from: allFetchedUsers[serviceIdToTry]!!, in: servicesToFetch).flatMap(fetchStep)
		}
		
		return try getUsers(from: dsuIdPair.dsuPair(), in: services).flatMap(fetchStep)
	}
	
	public static func merge(dsuPairs: Set<AnyDSUPair>, eventLoop: EventLoop, dispatchQueue: DispatchQueue = defaultDispatchQueueForFutureSupport) -> EventLoopFuture<[MultiServicesUser]> {
		let promise = eventLoop.newPromise([MultiServicesUser].self)
		dispatchQueue.async{
			do {
				/* Transform the input to get something we can use (DSUPairs to LinkedUsers + extracting the list of services). */
				let services: [AnyDirectoryService]
				let linkedUsersByDSUPair: [AnyDSUPair: LinkedUser]
				do {
					var servicesIds = Set<String>()
					var servicesBuilding = [AnyDirectoryService]()
					var linkedUsersByDSUPairBuilding = [AnyDSUPair: LinkedUser](minimumCapacity: dsuPairs.count)
					for pair in dsuPairs {
						assert(linkedUsersByDSUPairBuilding[pair] == nil)
						linkedUsersByDSUPairBuilding[pair] = LinkedUser(dsuPair: pair)
						if servicesIds.insert(pair.serviceId).inserted {servicesBuilding.append(pair.service)}
					}
					linkedUsersByDSUPair = linkedUsersByDSUPairBuilding
					services = servicesBuilding
				}
				
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
					
					var res: [String: AnyDSUPair] = [linkedUser.dsuPair.serviceId: linkedUser.dsuPair]
					for subLinkedUser in linkedUser.linkedUserByServiceId.values {
						guard !treatedDSUPairs.contains(subLinkedUser.dsuPair) else {
							throw InternalError(message: "Got already treated linked user! \(subLinkedUser.dsuPair) for \(dsuPair)")
						}
						guard res[subLinkedUser.dsuPair.serviceId] == nil else {
							throw InternalError(message: "Got two users for service id \(subLinkedUser.dsuPair.serviceId): \(res[subLinkedUser.dsuPair.serviceId]!) and \(subLinkedUser.dsuPair)")
						}
						res[subLinkedUser.dsuPair.serviceId] = subLinkedUser.dsuPair
						treatedDSUPairs.insert(subLinkedUser.dsuPair)
					}
					return MultiServicesUser(pairsByServiceId: res)
				}
				
				promise.succeed(result: results)
			} catch {
				promise.fail(error: error)
			}
		}
		return promise.futureResult
	}
	
	public let errorsAndPairsByServiceId: [String: Result<AnyDSUPair?, Error>]
	public let pairsByServiceId: [String: AnyDSUPair?]
	public let errorsByServiceId: [String: Error]
	
	public let services: Set<String>
	
	/** Creates the MultiServicesUser with the given pairs and errors. If, for a
	given service there is a user and some errors, the user will be chosen. */
	init(pairsByServiceId pbsi: [String: AnyDSUPair?] = [:], errorsByServiceId ebsi: [String: Error] = [:]) {
		self.init(errorsAndPairsByServiceId: pbsi.mapValues{ .success($0) }.merging(ebsi.mapValues{ .failure($0) }, uniquingKeysWith: { old, _ in old }))
	}
	
	init(errorsAndPairsByServiceId eapbsi: [String: Result<AnyDSUPair?, Error>]) {
		errorsAndPairsByServiceId = eapbsi
		pairsByServiceId = eapbsi.compactMapValues{ $0.successValue }
		errorsByServiceId = eapbsi.compactMapValues{ $0.failureValue }
		services = Set(errorsAndPairsByServiceId.keys)
	}
	
	public subscript(serviceId: String) -> AnyDSUPair?? {
		return pairsByServiceId[serviceId]
	}
	
	public subscript<ServiceType : DirectoryService>(service: ServiceType) -> AnyDSUPair?? {
		return pairsByServiceId[service.config.serviceId]
	}
	
}
