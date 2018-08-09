/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import FluentSQLite
import Leaf
import URLRequestOperation
import Vapor

import OfficeKit



func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	di.log = nil /* Disable network logs */
	
	/* Register providers first */
	try services.register(FluentSQLiteProvider())
	try services.register(LeafProvider())
	
	/* We use the LeafRenderer by default */
	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	
	/* Register the AsyncConfig */
	services.register(AsyncConfig.self)
	
	/* Register routes to the router */
	let router = EngineRouter(caseInsensitive: true)
	try setup_routes(router)
	services.register(router, as: Router.self)
	
	/* Register middlewares */
	var middlewares = MiddlewareConfig()
	middlewares.use(FileMiddleware.self) /* Serves files from the “Public” directory */
	middlewares.use(ErrorMiddleware.self) /* Catches errors and converts them to HTTP response */
	services.register(middlewares)
	
	/* Now register the Guaka command wrapper. Guaka does the argument parsing
	 * because Vapor’s sucks :( */
	var commandConfig = CommandConfig()
	commandConfig.use(get_guaka_command(), as: "guaka", isDefault: true)
	services.register(commandConfig)
}
