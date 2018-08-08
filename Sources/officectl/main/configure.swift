/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import FluentSQLite
import URLRequestOperation
import Vapor

import OfficeKit



func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	di.log = nil /* Disable network logs */
	
	/* Register providers first */
	try services.register(FluentSQLiteProvider())
	
	/* Register routes to the router */
	let router = EngineRouter(caseInsensitive: true)
	try setup_routes(router)
	services.register(router, as: Router.self)
	
	/* Register the AsyncConfigFactory */
	services.register(AsyncConfigFactory())
	
	/* Now register the Guaka command wrapper. Guaka does the argument parsing
	 * because Vapor’s sucks :( */
	var commandConfig = CommandConfig()
	commandConfig.use(get_guaka_command(), as: "guaka", isDefault: true)
	services.register(commandConfig)
}
