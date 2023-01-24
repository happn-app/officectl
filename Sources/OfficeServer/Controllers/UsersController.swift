/*
 * UsersController.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation

import UnwrapOrThrow
import Vapor

import OfficeKit
import OfficeModel



struct UsersController : RouteCollection {
	
	func boot(routes: RoutesBuilder) throws {
		let auth = routes//.grouped(AuthToken.authenticator(), AuthToken.guardMiddleware())
		let usersRoute = auth.grouped("users")
		usersRoute.get(use: listUsers)
	}
	
	func listUsers(req: Request) async throws -> ApiUsers {
//		let authToken = try req.auth.require(AuthToken.self)
		let serviceIDs = try req.query.get(String?.self, at: "service_ids")
		let userServices = req.application.officeKitServices.hashableUserServices(matching: serviceIDs)
		let (users, fetchErrors) = try await MultiServicesUser.fetchAll(in: userServices, propertiesToFetch: nil, includeSuspended: true)
		let errors: [Tag: Result<None, ApiError>] = Dictionary(uniqueKeysWithValues: userServices.map{ service in
			(service.value.id, fetchErrors[service].flatMap{ .failure(ApiError(error: $0)) } ?? .success(None()))
		})
		return ApiUsers(
			mergedResults: users.map{ ApiUser(multiServicesUser: $0, servicesMergePriority: [], logger: req.logger) },
			results: errors
		)
	}
	
}
