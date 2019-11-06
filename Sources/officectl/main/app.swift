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
	let app = try Application(environment: env)
	try configure(app)
	
	try boot(app)
	return app
}
