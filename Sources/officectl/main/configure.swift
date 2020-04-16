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
	 * wanted CLI-wise with Vapor) :(
	 * NOTE: I did not try again w/ Vapor 4… */
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
	app.leaf.tags[IsEmptyLeafTag.name] = IsEmptyLeafTag()
	app.leaf.tags[SnailCaseToHumanLeafTag.name] = SnailCaseToHumanLeafTag()
	app.leaf.tags[DictionaryGetValueForDynKeyLeafTag.name] = DictionaryGetValueForDynKeyLeafTag()
	
	/* Set OfficeKit options */
	WeakeningMode.defaultMode = .onSuccess(delay: 13*60) /* 13 minutes */
	
	/* Register the routes and middlewares */
	try setup_routes_and_middlewares(app)
	
	/* Register the Guaka command wrapper. Guaka does the argument parsing
	 * because I wasn’t able to do what I wanted with Vapor’s :(
	 * Note I did not retry with Vapor 4. Maybe it has a way to do what I want. */
	app.commands.defaultCommand = cliParseResults.wrapperCommand
	app.commands.use(cliParseResults.wrapperCommand, as: "guaka", isDefault: true)
}
