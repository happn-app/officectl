/*
 * app.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import Vapor



func app() throws -> Application {
	var env = try Environment.detect(arguments: [CommandLine.arguments[0], "guaka"]) /* Guaka will parse the CL arguments */
	var config = Config.default()
	var services = Services.default()
	try configure(&config, &env, &services)
	
	let app = try Application(config: config, environment: env, services: services)
	try boot(app)
	
	return app
}
