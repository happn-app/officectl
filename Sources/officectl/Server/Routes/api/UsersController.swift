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
		let officectlConfig = req.application.officectlConfig
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token: ApiAuth.Token = try JWTSigner.hs256(key: officectlConfig.jwtSecret).verify(bearer.token)
		
		/* Only admins are allowed to list the users. */
		guard token.adm else {
			throw Abort(.forbidden)
		}
		
//		let logger = req.make(Logger.self)
		let sProvider = req.application.officeKitServiceProvider
		
		let serviceIdsStr: String? = req.query["service_ids"]
		let serviceIds = serviceIdsStr?.split(separator: ",").map(String.init)
		let services = try Set(serviceIds.flatMap{ try $0.map{ try sProvider.getUserDirectoryService(id: $0) } } ?? Array(sProvider.getAllUserDirectoryServices()))
		
		return try MultiServicesUser.fetchAll(in: services, using: req.services).flatMapThrowing{
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
		let officectlConfig = req.application.officectlConfig
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token: ApiAuth.Token = try JWTSigner.hs256(key: officectlConfig.jwtSecret).verify(bearer.token)
		
		let myUserId = try AnyDSUIdPair(taggedId: token.sub, servicesProvider: req.application.officeKitServiceProvider)
		return try getUserNoAuthCheck(userId: myUserId, request: req)
	}
	
	func getUser(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>> {
		/* General auth check */
		let officectlConfig = req.application.officectlConfig
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token: ApiAuth.Token = try JWTSigner.hs256(key: officectlConfig.jwtSecret).verify(bearer.token)
		
		/* Parameter retrieval */
		let userId = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		
		/* Only admins are allowed to see any user. Other users can only see
		 * themselves. */
		guard try token.adm || token.representsSameUserAs(dsuIdPair: userId, request: req) else {
			throw Abort(.forbidden)
		}
		
		return try getUserNoAuthCheck(userId: userId, request: req)
	}
	
	private func getUserNoAuthCheck(userId: AnyDSUIdPair, request: Request) throws -> EventLoopFuture<ApiResponse<ApiUserSearchResult>> {
		let officeKitConfig = request.application.officeKitConfig
		let sProvider = request.application.officeKitServiceProvider
		return try MultiServicesUser.fetch(from: userId, in: sProvider.getAllUserDirectoryServices(), using: request.services)
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
