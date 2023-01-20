/*
 * ServicesController.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/20.
 */

import Foundation

import UnwrapOrThrow
import Vapor

import OfficeKit
import OfficeModel



struct ServicesController : RouteCollection {
	
	func boot(routes: RoutesBuilder) throws {
		let auth = routes//.grouped(AuthToken.authenticator(), AuthToken.guardMiddleware())
		let servicesRoute = auth.grouped("services")
		servicesRoute.get(use: listServices)
	}
	
	func listServices(req: Request) async throws -> [ApiService] {
		//		let authToken = try req.auth.require(AuthToken.self)
		/* TODO: Auth (of course) and filter for user services, etc. */
		return req.application.officeKitServices.allServices.values
			.map{ ApiService(providerID: type(of: $0).providerID, serviceID: $0.id, serviceFullName: $0.name) }
	}
	
}
