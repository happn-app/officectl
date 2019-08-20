/*
 * MultiServicesUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 19/08/2019.
 */

import Foundation

import NIO



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
	
	public let pairsByServiceId: [String: AnyDSUPair]
	
	public var services: Set<String> {
		return Set(pairsByServiceId.keys)
	}
	
	public subscript(serviceId: String) -> AnyDSUPair? {
		return pairsByServiceId[serviceId]
	}
	
	public subscript<ServiceType : DirectoryService>(service: ServiceType) -> AnyDSUPair? {
		return pairsByServiceId[service.config.serviceId]
	}
	
}
