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
	
	func getAllUsers(_ req: Request) async throws -> ApiUsers {
		let sProvider = req.application.officeKitServiceProvider
		
		let serviceIDsStr: String? = req.query["service_ids"]
		let serviceIDs = serviceIDsStr?.split(separator: ",").map(String.init)
		let services = try Set(serviceIDs.flatMap{ try $0.map{ try sProvider.getUserDirectoryService(id: $0) } } ?? Array(sProvider.getAllUserDirectoryServices()))
		
		let (users, fetchErrorsByService) = try await MultiServicesUser.fetchAll(in: services, using: req.services)
		let orderedServices = try req.application.officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceID) }
		return try ApiUsers(
			users: users,
			fetchErrorsByServices: fetchErrorsByService,
			orderedServices: orderedServices,
			environment: req.application.environment
		)
	}
	
	func getMe(_ req: Request) async throws -> ApiUser {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		return try await getUserNoAuthCheck(userID: loggedInUser.user.dsuIDPair, request: req)
	}
	
	func getUser(_ req: Request) async throws -> ApiUser {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let fetchedUserID = try AnyDSUIDPair.getAsParameter(named: "dsuid-pair", from: req)
		guard try loggedInUser.scopes.contains(.admin) || loggedInUser.representsSameUserAs(dsuIDPair: fetchedUserID, request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only see themselves.")
		}
		
		return try await getUserNoAuthCheck(userID: fetchedUserID, request: req)
	}
	
	private func getUserNoAuthCheck(userID: AnyDSUIDPair, request: Request) async throws -> ApiUser {
		let officeKitConfig = request.application.officeKitConfig
		let sProvider = request.application.officeKitServiceProvider
		let multiUser = try await MultiServicesUser.fetch(from: userID, in: sProvider.getAllUserDirectoryServices(), using: request.services)
		let orderedServices = try officeKitConfig.orderedServiceConfigs.map{ try sProvider.getUserDirectoryService(id: $0.serviceID) }
		return try ApiUser(user: multiUser, orderedServices: orderedServices, environment: request.application.environment)
	}
	
}
