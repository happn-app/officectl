/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

//import FluentSQLite
import Leaf
import SemiSingleton
import URLRequestOperation
import Vapor

import OfficeKit



func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	/* Let’s parse the CL arguments with Guaka (I did not find a way to do what I
	 * wanted CLI-wise with Vapor) :( */
	let cliParseResults = parse_cli()
	configureSemiSingleton(cliParseResults.officectlConfig)
	configureRetryingOperation(cliParseResults.officectlConfig)
	configureURLRequestOperation(cliParseResults.officectlConfig)
	/* Register the services/configs we got from CLI, if any */
	services.register(cliParseResults.officectlConfig)
	if let p = cliParseResults.officectlConfig.staticDataDirURL?.path {
		services.register{ container -> DirectoryConfig in
			return DirectoryConfig(workDir: p.hasSuffix("/") ? p : p + "/")
		}
	}
	
	/* Register providers */
//	try services.register(FluentSQLiteProvider())
	try services.register(LeafProvider())
	
	/* Register Services */
	services.register(ErrorMiddleware.self)
	services.register(SemiSingletonStore(forceClassInKeys: true))
	services.register(OfficeKitServiceProvider(config: cliParseResults.officectlConfig.officeKitConfig))
	
	/* Register routes */
	let router = EngineRouter(caseInsensitive: true)
	try setup_routes(router)
	services.register(router, as: Router.self)
	
	/* Register middlewares */
	var middlewares = MiddlewareConfig()
	middlewares.use(AsyncErrorMiddleware(processErrorHandler: handleOfficectlError)) /* Catches errors and converts them to HTTP response */
	middlewares.use(FileMiddleware.self) /* Serves files from the “Public” directory */
	services.register(middlewares)
	
	/* Set preferred services */
	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	
	/* Set OfficeKit options */
	WeakeningMode.defaultMode = .onSuccess(delay: 13*60) /* 13 minutes */
	
	/* Register the Guaka command wrapper. Guaka does the argument parsing
	 * because I wasn’t able to do what I wanted with Vapor’s :( */
	var commandConfig = CommandConfig()
	commandConfig.use(cliParseResults.wrapperCommand, as: "guaka", isDefault: true)
	services.register(commandConfig)
}


private func handleOfficectlError(request: Request, chainingTo next: Responder, error: Error) throws -> Future<Response> {
	let status = (error as? Abort)?.status
	let is404 = status?.code == 404
	let context = [
		"error_title": is404 ? "Page Not Found" : "Unknown Error",
		"error_description": is404 ? "This page was not found. Please go away!" : "\(error)"
	]
	if request.http.url.pathComponents.first == "/" && request.http.url.pathComponents.dropFirst().first == "api" {
//		return try request.make(ErrorMiddleware.self).respond(to: request, chainingTo: next)
		let response = try request.response(http: HTTPResponse(
			status: status ?? .internalServerError,
			headers: (error as? Abort)?.headers ?? [:],
			body: JSONEncoder().encode(error.asApiResponse(environment: request.environment))
		))
		return request.future(response)
	} else {
		return try request.view().render("ErrorPage", context).then{ view in
			return view.encode(status: status ?? .internalServerError, for: request)
		}
	}
}
