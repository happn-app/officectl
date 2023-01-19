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
		let (users, fetchErrors) = try await MultiServicesUser.fetchAll(in: userServices, propertiesToFetch: nil, includeSuspended: true, using: req.services)
		let errors: [String: Result<None, ApiError>] = Dictionary(uniqueKeysWithValues: userServices.map{ service in
			(service.value.id, fetchErrors[service].flatMap{ _ in .failure(ApiError(code: 1, domain: "yolo", message: "amazing error")) } ?? .success(None()))
		})
		return ApiUsers(results: errors, mergedResults: users.map{ user in
			let directoryUsers: [String: Result<ApiDirectoryUser?, ApiError>] = user
				.mapKeys{ $0.value.id }
				.mapValues{ userResult in
					userResult
						.mapError{ _ in ApiError(code: 1, domain: "yolo", message: "amazing error") }
						.map{ optionalUser in optionalUser.flatMap{ user in ApiDirectoryUser(
							serviceID: "yolo", userID: "yolo", persistentID: nil,
							isSuspended: user.oU_isSuspended, firstName: user.oU_firstName, lastName: user.oU_lastName, nickname: user.oU_nickname,
							emails: user.oU_emails, nonStandardProperties: [:]
						) } }
				}
			return ApiMergedUserWithSource(directoryUsers: directoryUsers)
		})
	}
	
}
