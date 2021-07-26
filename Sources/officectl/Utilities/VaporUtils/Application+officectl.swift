/*
 * Application+Officectl.swift
 * officectl
 *
 * Created by François Lamboley on 11/06/2020.
 */

import Foundation

import CLTLogger
import NIO
import OfficeKit
import Vapor



extension Application {
	
	static func runSync(officectlConfig: OfficectlConfig, configureHandler: (_ app: Application) throws -> Void, _ runHandler: @escaping (_ commandContext: CommandContext) throws -> EventLoopFuture<Void>) throws {
		var env = Environment(officectlConfig: officectlConfig)
		try LoggingSystem.bootstrap(from: &env, { level in
			return { label in
				var ret = CLTLogger()
				ret.logLevel = level
				return ret
			}
		})
		
		/* TODO: Not sure this is the best place for this. Maybe it is. */
		if let caCertFile = officectlConfig.caCertFileURL {
			try LDAPConnector.setCA(caCertFile)
		}
		
		let app = Application(env)
		do    {try officectlConfig.configureVaporApp(app); try configureHandler(app)}
		catch {app.shutdown(); throw error}
		
		/* We register a handler command that will run our handler. */
		let vaporCommand = HandlerVaporCommand(run: runHandler)
		app.commands.defaultCommand = vaporCommand
		app.commands.use(vaporCommand, as: "handler", isDefault: true)
		
		do {
			/* This whole block should be removed once storage is thread-safe (see
			 * https://github.com/vapor/vapor/issues/2330).
			 * In the mean time we force get all the properties that set something
			 * in the storage so the storage is effectively read-only later.
			 * Must be done after the app is configured. */
			_ = app.semiSingletonStore
			_ = app.officeKitServiceProvider
			_ = app.services
			_ = app.auditLogger
			_ = app.officectlStorage
		}
		
		defer {app.shutdown()}
		try app.run()
	}
	
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
		
		/* Arguments are parsed w/ ArgumentParser! Not Vapor. */
		self.arguments = ["fake vapor"]
	}
	
}
