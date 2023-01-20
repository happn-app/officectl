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

import OfficeModel



func routes(_ app: Application) throws {
	app.routes.get("_internal", "metrics", use: { _ in try await MetricsSystem.prometheus().collect() })
	
	let apiRoute = app.grouped("api", "v2")
//	try app.register(collection: AuthController())
	try apiRoute.register(collection: ServicesController())
	try apiRoute.register(collection: UsersController())
}
