/*
 * UsersController.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import GenericJSON
import JWT
import OfficeKit
import SemiSingleton
import Vapor



class UsersController {
	
	func getAllUsers(_ req: Request) throws -> Future<ApiResponse<ApiUsersSearchResult>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Only admins are allowed to list the users. */
		guard token.payload.adm else {
			throw Abort(.forbidden)
		}
		
		let logger = try? req.make(Logger.self)
		let sProvider = try req.make(OfficeKitServiceProvider.self)
		
		let serviceIdsStr: String? = req.query["service_ids"]
		let serviceIds = serviceIdsStr?.split(separator: ",").map(String.init)
		let services = try serviceIds.flatMap{ try $0.map{ try sProvider.getDirectoryService(id: $0) } } ?? sProvider.getAllServices()
		
		let serviceAndFutureUsers = services.map{ service in (service, req.future().flatMap{ try service.listAllUsers(on: req) }) }
		
		return Future.waitAll(serviceAndFutureUsers, eventLoop: req.eventLoop).flatMap{ servicesAndUserResults in
			let startComputationTime = Date()
			/* First let’s drop the unsuccessful users fetches */
			var fetchErrorsByService = [String: [ApiError]]()
			let userPairs = servicesAndUserResults.compactMap{ serviceAndUserResults -> [AnyDSUPair]? in
				let service = serviceAndUserResults.0
				switch serviceAndUserResults.1 {
				case .failure(let error):
					fetchErrorsByService[service.config.serviceId] = [ApiError(error: error, environment: req.environment)]
					return nil
					
				case .success(let users):
					return users.map{ AnyDSUPair(service: service, user: $0) }
				}
			}.flatMap{ $0 }
			
			/* Merge the users we fetched */
			let orderedServiceIds = officectlConfig.officeKitConfig.orderedServiceConfigs.map{ $0.serviceId }
			let validServiceIds = Set(services.map{ $0.config.serviceId }).subtracting(fetchErrorsByService.keys)
			return MultiServicesUser.merge(dsuPairs: Set(userPairs), eventLoop: req.eventLoop).map{
				let ret = try ApiResponse.data(ApiUsersSearchResult(request: "TODO", errorsByServiceId: fetchErrorsByService, result: $0.map{
					try ApiUser(multiUsers: $0, validServicesIds: validServiceIds, orderedServicesIds: orderedServiceIds)
				}))
				logger?.info("Computed merged users list in \(-startComputationTime.timeIntervalSinceNow) seconds")
				return ret
			}
		}
	}
	
	func getMe(_ req: Request) throws -> Future<ApiResponse<ApiUserSearchResult>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		let myUserId = try AnyDSUIdPair(taggedId: token.payload.sub, servicesProvider: req.make())
		return try getUserNoAuthCheck(userId: myUserId, container: req)
	}
	
	func getUser(_ req: Request) throws -> Future<ApiResponse<ApiUserSearchResult>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let userId = try req.parameters.next(AnyDSUIdPair.self)
		
		/* Only admins are allowed to see any user. Other users can only see
		 * themselves. */
		guard try token.payload.adm || token.payload.representsSameUserAs(dsuIdPair: userId, container: req) else {
			throw Abort(.forbidden)
		}
		
		return try getUserNoAuthCheck(userId: userId, container: req)
	}
	
	private func getUserNoAuthCheck(userId: AnyDSUIdPair, container: Container) throws -> Future<ApiResponse<ApiUserSearchResult>> {
		let logger = try? container.make(Logger.self)
		let sProvider = try container.make(OfficeKitServiceProvider.self)
		let officeKitConfig = try container.make(OfficectlConfig.self).officeKitConfig
		let (service, user) = try (userId.service, userId.service.logicalUser(fromUserId: userId.userId))
		
		let allServices = try sProvider.getAllServices()
		let servicesById = try allServices.group(by: { $0.config.serviceId })
		
		var allFetchedUsers = [String: AnyDirectoryUser?]()
		var allFetchedErrors = [String: [Error]]()
		var triedServiceIdSource = Set<String>()
		
		var nextFetchStepRec: ((_ fetchedUsersAndErrors: [String: Result<AnyDirectoryUser?, Error>]) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>>)!
		let nextFetchStep = { (fetchedUsersAndErrors: [String: Result<AnyDirectoryUser?, Error>]) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>> in
			/* Try and fetch the users that were not successfully fetched. */
			allFetchedUsers  = allFetchedUsers.merging(fetchedUsersAndErrors.compactMapValues{ $0.successValue }, uniquingKeysWith: { old, new in
				logger?.error("Got a user fetched twice for id \(String(describing: old?.userId ?? new?.userId)). old user = \(String(describing: old)), new user = \(String(describing: new))")
				return new
			})
			
			allFetchedErrors = allFetchedErrors.merging(fetchedUsersAndErrors.compactMapValues{ $0.failureValue.flatMap{ [$0] } }, uniquingKeysWith: { old, new in old + new })
			allFetchedErrors = allFetchedErrors.filter{ !allFetchedUsers.keys.contains($0.key) }
			
			#warning("TODO: Only try and re-fetched users whose fetch error was a “I don’t have enough info to fetch” error.")
			let servicesToFetch = allServices.filter{ allFetchedErrors.keys.contains($0.config.serviceId) }
			/* Line below: All the service ids for which we have a user that we do not already have tried fetching from. */
			let serviceIdsToTry = Set(allFetchedUsers.compactMap{ $0.value != nil ? $0.key : nil }).subtracting(triedServiceIdSource)
			
			guard let serviceIdToTry = serviceIdsToTry.first, servicesToFetch.count > 0 else {
				var allFetchedUserWrappers = [String: DirectoryUserWrapper?]()
				for (serviceId, user) in allFetchedUsers {
					do    {allFetchedUserWrappers[serviceId] = try user.flatMap{ try servicesById[serviceId]!.wrappedUser(fromUser: $0) }}
					catch {allFetchedErrors[serviceId] = (allFetchedErrors[serviceId] ?? []) + [error]}
				}
				
				let orderedServiceIds = officeKitConfig.orderedServiceConfigs.map{ $0.serviceId }
				let res = ApiResponse.data(
					ApiUserSearchResult(
						request: userId.taggedId,
						errorsByServiceId: allFetchedErrors.mapValues{ $0.map{ ApiError(error: $0, environment: container.environment) } },
						result: ApiUser(usersByServiceId: allFetchedUserWrappers, orderedServicesIds: orderedServiceIds)
					)
				)
				return container.eventLoop.newSucceededFuture(result: res)
			}
			
			triedServiceIdSource.insert(serviceIdToTry)
			return self.getUsersNoAuthCheck(from: allFetchedUsers[serviceIdToTry]!!, in: servicesById[serviceIdToTry]!, for: servicesToFetch, container: container)
			.flatMap(nextFetchStepRec)
		}
		nextFetchStepRec = nextFetchStep
		
		/* First, we try and fetch the users directly from the source logical user
		 * (from the tagged id given in input). */
		return getUsersNoAuthCheck(from: user, in: service, for: allServices, container: container)
		.flatMap(nextFetchStep)
	}
	
	private func getUsersNoAuthCheck(from user: AnyDirectoryUser, in service: AnyDirectoryService, for services: [AnyDirectoryService], container: Container) -> EventLoopFuture<[String: Result<AnyDirectoryUser?, Error>]> {
		let userFutures = services.map{ curService in
			container.future().flatMap{
				try curService.existingUser(fromUser: user, in: service, propertiesToFetch: [], on: container)
			}
		}
		return Future.waitAll(userFutures, eventLoop: container.eventLoop).map{ userResults in
			var res = [String: Result<AnyDirectoryUser?, Error>]()
			for (idx, userResult) in userResults.enumerated() {
				let service = services[idx]
				res[service.config.serviceId] = userResult.map{ curUser in curUser?.erased() }
			}
			return res
		}
	}
	
}
