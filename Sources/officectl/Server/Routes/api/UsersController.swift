/*
 * UsersController.swift
 * officectl
 *
 * Created by François Lamboley on 2019/03/01.
 */

import Foundation

import GenericJSON
import JWT
import OfficeKit
import OfficeModel
import SemiSingleton
import Vapor



class UsersController {
	
	func getAllUsers(_ req: Request) async throws -> ApiUsersSearchResult {
		let sProvider = req.application.officeKitServiceProvider
		
		let serviceIDsStr: String? = req.query["service_ids"]
		let serviceIDs = serviceIDsStr?.split(separator: ",").map(String.init)
		let services = try Set(serviceIDs.flatMap{ try $0.map{ try sProvider.getUserDirectoryService(id: $0) } } ?? Array(sProvider.getAllUserDirectoryServices()))
		
		let (users, fetchErrorsByService) = try await MultiServicesUser.fetchAll(in: services, using: req.services)
		let fetchApiErrorsByService = fetchErrorsByService.mapValues{ ApiError(error: $0, environment: req.application.environment) }
		let orderedServices = try req.application.officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceID) }
		return try ApiUsersSearchResult(request: "TODO", errorsByServiceID: fetchApiErrorsByService.mapKeys{ $0.config.serviceID }, result: users.map{
			try ApiUser(multiUsers: $0, orderedServices: orderedServices)
		}.sorted{ ($0.lastName ?? "").localizedCompare($1.lastName ?? "") != .orderedDescending })
	}
	
	func getMe(_ req: Request) async throws -> ApiUserSearchResult {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		return try await getUserNoAuthCheck(userID: loggedInUser.user.dsuIDPair, request: req)
	}
	
	func getUser(_ req: Request) async throws -> ApiUserSearchResult {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let fetchedUserID = try AnyDSUIDPair.getAsParameter(named: "dsuid-pair", from: req)
		guard try loggedInUser.scopes.contains(.admin) || loggedInUser.representsSameUserAs(dsuIDPair: fetchedUserID, request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only see themselves.")
		}
		
		return try await getUserNoAuthCheck(userID: fetchedUserID, request: req)
	}
	
	private func getUserNoAuthCheck(userID: AnyDSUIDPair, request: Request) async throws -> ApiUserSearchResult {
		let officeKitConfig = request.application.officeKitConfig
		let sProvider = request.application.officeKitServiceProvider
		let multiUser = try await MultiServicesUser.fetch(from: userID, in: sProvider.getAllUserDirectoryServices(), using: request.services)
		let orderedServices = try officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceID) }
		return try ApiUserSearchResult(
			request: userID.taggedID,
			errorsByServiceID: Dictionary(uniqueKeysWithValues: multiUser.errorsByService.map{ ($0.key.config.serviceID, ApiError(error: $0.value, environment: request.application.environment)) }),
			result: ApiUser(multiUsers: multiUser, orderedServices: orderedServices)
		)
	}
	
}
