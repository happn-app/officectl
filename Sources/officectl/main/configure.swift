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



func configure(_ app: Application) throws {
	/* Let’s parse the CL arguments with Guaka (I did not find a way to do what I
	 * wanted CLI-wise with Vapor) :( */
	let cliParseResults = parse_cli(app)
	configureSemiSingleton(cliParseResults.officectlConfig)
	configureRetryingOperation(cliParseResults.officectlConfig)
	configureURLRequestOperation(cliParseResults.officectlConfig)
	/* Register the services/configs we got from CLI, if any */
	app.officectlConfig = cliParseResults.officectlConfig
	if let p = cliParseResults.officectlConfig.staticDataDirURL?.path {
		app.directory = DirectoryConfiguration(workingDirectory: p.hasSuffix("/") ? p : p + "/")
	}
	
	/* Don’t know how to do that anymore, but should be the default anyway. */
//	app.register(LeafConfig.self, { app in return LeafConfig(rootDirectory: app.make(DirectoryConfiguration.self).viewsDirectory) })
	/* Tell the views we want to use Leaf as a renderer. */
	app.views.use(.leaf)
	
	/* Register routes */
	try setup_routes(app)
	
	/* Register middlewares */
	app.middleware.use(AsyncErrorMiddleware(processErrorHandler: handleOfficectlError)) /* Catches errors and converts them to HTTP response */
	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory)) /* Serves files from the “Public” directory */
	
	/* Set preferred services (not available in Vapor 4 anymore?) */
//	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	
	/* Set OfficeKit options */
	WeakeningMode.defaultMode = .onSuccess(delay: 13*60) /* 13 minutes */
	
	/* Register the Guaka command wrapper. Guaka does the argument parsing
	 * because I wasn’t able to do what I wanted with Vapor’s :(
	 * Note I did not retry with Vapor 4. Maybe it has a way to do what I want. */
	app.commands.defaultCommand = cliParseResults.wrapperCommand
	app.commands.use(cliParseResults.wrapperCommand, as: "guaka", isDefault: true)
}


private func handleOfficectlError(request: Request, chainingTo next: Responder, error: Error) throws -> EventLoopFuture<Response> {
	#warning("TODO: Log the error")
	
	let status = (error as? Abort)?.status
	let is404 = status?.code == 404
	let context = [
		"errorTitle": is404 ? "Page Not Found" : "Unknown Error",
		"errorDescription": is404 ? "This page was not found. Please go away!" : "\(error)"
	]
	
	if request.url.path.drop(while: { $0 == "/" }).hasPrefix("api/") {
		let response = Response(status: status ?? .internalServerError, headers: (error as? Abort)?.headers ?? [:])
		response.body = try .init(data: JSONEncoder().encode(error.asApiResponse(environment: request.application.environment)))
		response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
		return request.eventLoop.makeSucceededFuture(response)
	} else {
		return request.view.render("ErrorPage", context).flatMap{ view in
			return view.encodeResponse(status: status ?? .internalServerError, for: request)
		}
	}
}
