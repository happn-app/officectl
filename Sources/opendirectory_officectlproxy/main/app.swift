/*
 * app.swift
 * officectl
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import Vapor



func app(_ env: Environment) throws -> Application {
	let forcedConfigPath: String?
	if let idx = env.arguments.lastIndex(where: { $0 == "--config-file" }), idx + 1 < env.arguments.count {
		forcedConfigPath = env.arguments[idx+1]
	} else {
		forcedConfigPath = nil
	}
	
	var config = Config.default()
	var env = env
	var services = Services.default()
	try configure(&config, &env, &services, forcedConfigPath: forcedConfigPath)
	
	let app = try Application(config: config, environment: env, services: services)
	try boot(app)
	
	return app
}
