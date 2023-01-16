/*
 * configure.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import Metrics
import Prometheus
import Vapor



func routes(_ app: Application) throws {
	app.routes.get("_internal", "metrics", use: { _ in try await MetricsSystem.prometheus().collect() })
	
//	try app.register(collection: AuthController())
}
