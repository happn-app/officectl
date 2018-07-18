/*
 * GitHubJWTConnector+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 18/07/2018.
 */

import Foundation

import Guaka

import OfficeKit



extension GitHubJWTConnector {
	
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
		try self.init(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
	}
	
}
