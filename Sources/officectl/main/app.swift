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
	/* Let’s parse the CL arguments with Guaka (I did not find a way to do what I
	 * wanted CLI-wise with Vapor) :( */
	let cliParseResults = parse_cli()
	
	var env = Environment(officectlConfig: cliParseResults.officectlConfig)
	try LoggingSystem.bootstrap(from: &env)
	
	let app = Application(env)
	try configure(app, cliParseResults: cliParseResults)
	
	/* Because Guaka parses the CLI, it also launches the app. */
	app.commands.defaultCommand = cliParseResults.wrapperCommand
	app.commands.use(cliParseResults.wrapperCommand, as: "guaka", isDefault: true)
	
	do {
		/* This whole block should be removed once storage is thread-safe (see https://github.com/vapor/vapor/issues/2330).
		 * In the mean time we force get all the properties that set something in
		 * the storage so the storage is effectively read-only later.
		 * Must be done after the app is configured. */
		_ = app.semiSingletonStore
		_ = app.officeKitServiceProvider
		_ = app.services
		_ = app.auditLogger
		_ = app.officectlStorage
	}
	
	return app
}


private extension Environment {
	
	init(officectlConfig: OfficectlConfig) {
		/* Default (`env` is `nil` in the config) is `.development`. */
		switch officectlConfig.env {
		case "dev", "development", nil: self = .development
		case "prod", "production": self = .production
		case "test", "testing": self = .testing
		case let str?: self.init(name: str)
		}
		
		/* Arguments are parsed w/ Guaka! Not Vapor. */
		self.arguments = ["fake vapor"]
	}
	
}
