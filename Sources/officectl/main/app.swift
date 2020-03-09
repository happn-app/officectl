/*
 * app.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



func app() throws -> Application {
	/* TODO: Log level… We will probably have to parse the CLI here instead of in
	 *       the configure. */
	LoggingSystem.bootstrap(console: Terminal(), level: .info)
	
	let env = try Environment.detect(arguments: [CommandLine.arguments[0], "guaka"]) /* Guaka will parse the CL arguments */
	let app = Application(env)
	try configure(app)
	
	OfficeKitConfig.logger = app.logger
	return app
}
