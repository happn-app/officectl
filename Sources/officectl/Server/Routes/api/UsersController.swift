/*
 * UsersController.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import GenericJSON
import JWTKit
import OfficeKit
import SemiSingleton
import Vapor



class UsersController {
	
	func getAllUsers(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiUsersSearchResult>> {
		/* General auth check */
		let officectlConfig = req.make(OfficectlConfig.self)
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: Data(bearer.token.utf8), verifiedBy: .hs256(key: officectlConfig.jwtSecret))
		
		/* Only admins are allowed to list the users. */
		guard token.payload.adm else {
			throw Abort(.forbidden)
		}
		
//		let logger = req.make(Logger.self)
		let sProvider = req.make(OfficeKitServiceProvider.self)
		
		let serviceIdsStr: String? = req.query["service_ids"]
		let serviceIds = serviceIdsStr?.split(separator: ",").map(String.init)
		let services = try Set(serviceIds.flatMap{ try $0.map{ try sProvider.getUserDirectoryService(id: $0) } } ?? Array(sProvider.getAllUserDirectoryServices()))
		
		return try MultiServicesUser.fetchAll(in: services, on: req.eventLoop).flatMapThrowing{
			let (users, fetchErrorsByService) = $0
			let fetchApiErrorsByService = fetchErrorsByService.mapValues{ ApiError(error: $0, environment: req.application.environment) }
			let orderedServices = try officectlConfig.officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceId) }
			return try ApiResponse.data(ApiUsersSearchResult(request: "TODO", errorsByServiceId: fetchApiErrorsByService.mapKeys{ $0.config.serviceId }, result: users.map{
				try ApiUser(multiUsers: $0, orderedServices: orderedServices)
			}.sorted{ ($0.lastName ?? "").localizedCompare($1.lastName ?? "") != .orderedDescending }))
		}
	}
	
	func getMe(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>> {
		/* General auth check */
		let officectlConfig = req.make(OfficectlConfig.self)
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: Data(bearer.token.utf8), verifiedBy: .hs256(key: officectlConfig.jwtSecret))
		
		let myUserId = try AnyDSUIdPair(taggedId: token.payload.sub, servicesProvider: req.make())
		return try getUserNoAuthCheck(userId: myUserId, request: req)
	}
	
	func getUser(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>> {
		/* General auth check */
		let officectlConfig = req.make(OfficectlConfig.self)
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: Data(bearer.token.utf8), verifiedBy: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let userId = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		
		/* Only admins are allowed to see any user. Other users can only see
		 * themselves. */
		guard try token.payload.adm || token.payload.representsSameUserAs(dsuIdPair: userId, request: req) else {
			throw Abort(.forbidden)
		}
		
		return try getUserNoAuthCheck(userId: userId, request: req)
	}
	
	private func getUserNoAuthCheck(userId: AnyDSUIdPair, request: Request) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>> {
		let sProvider = request.make(OfficeKitServiceProvider.self)
		let officeKitConfig = request.make(OfficectlConfig.self).officeKitConfig
		return try MultiServicesUser.fetch(from: userId, in: sProvider.getAllUserDirectoryServices(), on: request.eventLoop)
		.flatMapThrowing{ multiUser in
			let orderedServices = try officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceId) }
			return try ApiResponse.data(
				ApiUserSearchResult(
					request: userId.taggedId,
					errorsByServiceId: Dictionary(uniqueKeysWithValues: multiUser.errorsByService.map{ ($0.key.config.serviceId, ApiError(error: $0.value, environment: request.application.environment)) }),
					result: ApiUser(multiUsers: multiUser, orderedServices: orderedServices)
				)
			)
		}
	}
	
}
