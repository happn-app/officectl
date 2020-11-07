/*
 * GlobalVaporConfig.swift
 * officectl
 *
 * Created by François Lamboley on 11/06/2020.
 */

import Foundation

import LeafKit
import OfficeKit
import RetryingOperation
import SemiSingleton
import URLRequestOperation
import Vapor



extension OfficectlConfig {
	
	func configureVaporApp(_ app: Application) throws {
		SemiSingletonConfig.oslog = nil
		SemiSingletonConfig.logger = app.logger
		RetryingOperationConfig.oslog = nil
		RetryingOperationConfig.logger = app.logger
		URLRequestOperationConfig.oslog = nil
		URLRequestOperationConfig.logger = app.logger
		
		/* Register the services/configs we got from CLI, if any */
		app.officectlConfig = self
		if let p = staticDataDirURL?.path {
			app.directory = DirectoryConfiguration(workingDirectory: p.hasSuffix("/") ? p : p + "/")
		}
		
		/* Add some tags to LeafKit and tell the views we want to use Leaf as a renderer. */
		LeafConfiguration.entities.use(SnailCaseToHumanLeafMethod(), asMethod: SnailCaseToHumanLeafMethod.name)
		app.views.use(.leaf)
		
		/* We use the memory store for the sessions for now (rebooting officectl
		 * will drop the sessions…). This is the default but we make it explicit. */
		app.sessions.use(.memory)
		
		/* Set OfficeKit options */
		OfficeKitConfig.logger = app.logger
		WeakeningMode.defaultMode = .onSuccess(delay: 13*60) /* 13 minutes */
	}
	
}
