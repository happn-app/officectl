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
	
	func getAllUsers(_ req: Request) async throws -> ApiResponse<ApiUsersSearchResult> {
		let sProvider = req.application.officeKitServiceProvider
		
		let serviceIdsStr: String? = req.query["service_ids"]
		let serviceIds = serviceIdsStr?.split(separator: ",").map(String.init)
		let services = try Set(serviceIds.flatMap{ try $0.map{ try sProvider.getUserDirectoryService(id: $0) } } ?? Array(sProvider.getAllUserDirectoryServices()))
		
		return try await MultiServicesUser.fetchAll(in: services, using: req.services).flatMapThrowing{
			let (users, fetchErrorsByService) = $0
			let fetchApiErrorsByService = fetchErrorsByService.mapValues{ ApiError(error: $0, environment: req.application.environment) }
			let orderedServices = try req.application.officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceId) }
			return try ApiResponse.data(ApiUsersSearchResult(request: "TODO", errorsByServiceId: fetchApiErrorsByService.mapKeys{ $0.config.serviceId }, result: users.map{
				try ApiUser(multiUsers: $0, orderedServices: orderedServices)
			}.sorted{ ($0.lastName ?? "").localizedCompare($1.lastName ?? "") != .orderedDescending }))
		}
		.get()
	}
	
	func getMe(_ req: Request) async throws -> ApiResponse<ApiUserSearchResult> {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		return try await getUserNoAuthCheck(userId: loggedInUser.user.dsuIdPair, request: req)
	}
	
	func getUser(_ req: Request) async throws -> ApiResponse<ApiUserSearchResult> {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let fetchedUserId = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		guard try loggedInUser.isAdmin || loggedInUser.representsSameUserAs(dsuIdPair: fetchedUserId, request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only see themselves.")
		}
		
		return try await getUserNoAuthCheck(userId: fetchedUserId, request: req)
	}
	
	private func getUserNoAuthCheck(userId: AnyDSUIdPair, request: Request) async throws -> ApiResponse<ApiUserSearchResult> {
		let officeKitConfig = request.application.officeKitConfig
		let sProvider = request.application.officeKitServiceProvider
		return try await MultiServicesUser.fetch(from: userId, in: sProvider.getAllUserDirectoryServices(), using: request.services)
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
		.get()
	}
	
}
