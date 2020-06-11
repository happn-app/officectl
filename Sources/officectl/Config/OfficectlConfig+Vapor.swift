/*
 * GlobalVaporConfig.swift
 * officectl
 *
 * Created by François Lamboley on 11/06/2020.
 */

import Foundation

import OfficeKit
import Vapor



extension OfficectlConfig {
	
	func configureVaporApp(_ app: Application) throws {
		configureSemiSingleton(self)
		configureRetryingOperation(self)
		configureURLRequestOperation(self)
		
		/* Register the services/configs we got from CLI, if any */
		app.officectlConfig = self
		if let p = staticDataDirURL?.path {
			app.directory = DirectoryConfiguration(workingDirectory: p.hasSuffix("/") ? p : p + "/")
		}
		
		/* Tell the views we want to use Leaf as a renderer and add some tags. */
		app.views.use(.leaf)
		app.leaf.tags[IsEmptyLeafTag.name] = IsEmptyLeafTag()
		app.leaf.tags[SnailCaseToHumanLeafTag.name] = SnailCaseToHumanLeafTag()
		app.leaf.tags[DictionaryGetValueForDynKeyLeafTag.name] = DictionaryGetValueForDynKeyLeafTag()
		
		/* We use the memory store for the sessions for now (rebooting officectl
		 * will drop the sessions…). This is the default but we make it explicit. */
		app.sessions.use(.memory)
		
		/* Set OfficeKit options */
		OfficeKitConfig.logger = app.logger
		WeakeningMode.defaultMode = .onSuccess(delay: 13*60) /* 13 minutes */
		
		/* Register the routes and middlewares */
		try setup_routes_and_middlewares(app)
	}
	
}
