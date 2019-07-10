/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import Vapor



public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	/* Register routes to the router */
	let router = EngineRouter.default()
	try routes(router)
	services.register(router, as: Router.self)
	
	/* Register middleware */
	var middlewares = MiddlewareConfig() /* Create _empty_ middleware config */
	middlewares.use(ErrorMiddleware.self) /* Catches errors and converts to HTTP response */
	services.register(middlewares)
}
