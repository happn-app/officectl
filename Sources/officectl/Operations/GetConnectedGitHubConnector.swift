/*
 * GetConnectedGitHubConnector.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import Guaka



class GetConnectedGitHubConnector : CommandOperation {
	
	let connector: GitHubJWTConnector
	
	override init(command cmd: Command, flags f: Flags, arguments args: [String]) {
		guard let privateKeyURLString = f.getString(name: "github-private-key") else {
			cmd.fail(statusCode: 1, errorMessage: "The github-private-key argument is required for commands dealing with GitHub APIs")
		}
		guard let appId = f.getString(name: "github-app-id") else {
			cmd.fail(statusCode: 1, errorMessage: "The github-app-id argument is required for commands dealing with GitHub APIs")
		}
		guard let installId = f.getString(name: "github-install-id") else {
			cmd.fail(statusCode: 1, errorMessage: "The github-install-id argument is required for commands dealing with GitHub APIs")
		}
		guard let c = GitHubJWTConnector(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false)) else {
			cmd.fail(statusCode: 1, errorMessage: "Cannot create the Google connector (does the credentials file exist?)")
		}
		
		connector = c
		
		super.init(command: cmd, flags: f, arguments: args)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		connector.connect(scope: (), handler: { error in
			guard self.connector.isConnected else {self.command.fail(statusCode: 1, errorMessage: error?.localizedDescription ?? "Unknown GitHub connection error")}
			self.baseOperationEnded()
		})
	}
	
}
