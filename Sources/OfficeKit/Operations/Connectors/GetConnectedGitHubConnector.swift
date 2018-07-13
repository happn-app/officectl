/*
 * GetConnectedGitHubConnector.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import Guaka
import RetryingOperation



public class GetConnectedGitHubConnector : RetryingOperation {
	
	public let connector: GitHubJWTConnector
	public var connectionError: Error?
	
	public convenience init(flags f: Flags) throws {
		guard let privateKeyURLString = f.getString(name: "github-private-key") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The github-private-key argument is required for commands dealing with GitHub APIs"])
		}
		guard let appId = f.getString(name: "github-app-id") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The github-app-id argument is required for commands dealing with GitHub APIs"])
		}
		guard let installId = f.getString(name: "github-install-id") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The github-install-id argument is required for commands dealing with GitHub APIs"])
		}
		guard let c = GitHubJWTConnector(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false)) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create the Google connector (does the credentials file exist?)"])
		}
		self.init(connector: c)
	}
	
	public init(connector c: GitHubJWTConnector) {
		connector = c
		
		super.init()
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		connector.connect(scope: (), handler: { error in
			if !self.connector.isConnected {
				self.connectionError = error ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown GitHub connection error"])
			}
			self.baseOperationEnded()
		})
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
