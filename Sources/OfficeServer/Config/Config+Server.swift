/*
 * Config+Server.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Metrics
import Prometheus
import Queues
import Vapor



public extension Conf {
	
	static func setupServer(_ app: Application) throws {
		scheduleServerJobs(app)
		
		try setupRoutes(app)
		try app.queues.startScheduledJobs()
	}
	
	static func setupRoutes(_ app: Application) throws {
		app.routes.get("_internal", "metrics", use: { _ in try await MetricsSystem.prometheus().collect() })
		
		let apiRoute = app.grouped("api", "v2")
//		try app.register(collection: AuthController())
		try apiRoute.register(collection: ServicesController())
		try apiRoute.register(collection: UsersController())
	}
	
	
	internal static func scheduleServerJobs(_ app: Application) {
		app.queues.schedule(UpdateCAMetricsJob()).daily().at(4, 30)
	}
	
}
