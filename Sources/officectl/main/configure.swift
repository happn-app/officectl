/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import FluentSQLite
import Leaf
import SemiSingleton
import URLRequestOperation
import Vapor

import OfficeKit



func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
//	di.log = nil /* Disable network logs */
	
	/* Let’s parse the CL arguments with Guaka (I did not find a way to do what I
	 * wanted CLI-wise with Vapor) :( */
	let cliParseResults = parse_cli()
	/* Register the services/configs we got from CLI, if any */
	cliParseResults.ldapConnectorConfig.flatMap{ services.register($0) }
	if let p = cliParseResults.staticDataDir?.path {
		services.register{ container -> DirectoryConfig in
			return DirectoryConfig(workDir: p.hasSuffix("/") ? p : p + "/")
		}
	}
	
	/* Register providers */
	try services.register(FluentSQLiteProvider())
	try services.register(LeafProvider())
	
	/* Register Services */
	services.register(AsyncConfig.self)
	services.register(AsyncErrorMiddleware.self)
	services.register(HTTPStatusToErrorMiddleware.self)
	services.register(SemiSingletonStore(forceClassInKeys: true))
	
	/* Register routes */
	let router = EngineRouter(caseInsensitive: true)
	try setup_routes(router)
	services.register(router, as: Router.self)
	
	/* Register middlewares */
	var middlewares = MiddlewareConfig()
	middlewares.use(AsyncErrorMiddleware(processErrorHandler: handleOfficectlError)) /* Catches errors and converts them to HTTP response */
	middlewares.use(FileMiddleware.self) /* Serves files from the “Public” directory */
	middlewares.use(HTTPStatusToErrorMiddleware.self) /* Convert “error” http status code from valid responses to actual errors */
	services.register(middlewares)
	
	/* Set preferred services */
	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	
	/* Register the Guaka command wrapper. Guaka does the argument parsing
	 * because I wasn’t able to do what I wanted with Vapor’s :( */
	var commandConfig = CommandConfig()
	commandConfig.use(cliParseResults.wrapperCommand, as: "guaka", isDefault: true)
	services.register(commandConfig)
}


private func handleOfficectlError(request: Request, error: Error) throws -> EventLoopFuture<Response> {
	let statusCode = (error as? HTTPStatusToErrorMiddleware.HTTPStatusError)?.originalResponse.status
	let is404 = statusCode?.code == 404
	let context = [
		"error_title": is404 ? "Page Not Found" : "Unknown Error",
		"error_description": is404 ? "This page was not found. Please go away!" : "\(error)"
	]
	return try request.view().render("ErrorPage", context).then{ view in
		return view.encode(status: statusCode ?? .internalServerError, for: request)
	}
}
