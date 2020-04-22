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
	
	OfficeKitConfig.logger = app.logger
	return app
}
