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
		let sProvider = try container.make(OfficeKitServiceProvider.self)
		let officeKitConfig = try container.make(OfficectlConfig.self).officeKitConfig
		return try MultiServicesUser.fetch(from: userId, in: sProvider.getAllServices(), on: container)
		.map{ multiUserAndErrors in
			let (multiUser, errorsByServiceId) = multiUserAndErrors
			let orderedServiceIds = officeKitConfig.orderedServiceConfigs.map{ $0.serviceId }
			return try ApiResponse.data(
				ApiUserSearchResult(
					request: userId.taggedId,
					errorsByServiceId: errorsByServiceId.mapValues{ $0.map{ ApiError(error: $0, environment: container.environment) } },
					result: ApiUser(multiUsers: multiUser, orderedServicesIds: orderedServiceIds)
				)
			)
		}
	}
	
}
