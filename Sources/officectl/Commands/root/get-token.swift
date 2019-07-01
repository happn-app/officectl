/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func getToken(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let asyncConfig = try context.container.make(AsyncConfig.self)
	let officeKitConfig = try context.container.make(OfficectlConfig.self).officeKitConfig
	
	let scopes = f.getString(name: "scopes")
	let serviceId = f.getString(name: "service-id")
	let serviceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	
	if let googleConfig: GoogleServiceConfig = serviceConfig.unwrapped() {
		return try getGoogleToken(googleConfig: googleConfig, scopesStr: scopes, asyncConfig: asyncConfig)
	}
	if let gitHubConfig: GitHubServiceConfig = serviceConfig.unwrapped() {
		return try getGitHubToken(gitHubConfig: gitHubConfig, scopesStr: scopes, asyncConfig: asyncConfig)
	}
	
	throw InvalidArgumentError(message: "Unsupported service to get a token from.")
}

private func getGoogleToken(googleConfig: GoogleServiceConfig, scopesStr: String?, asyncConfig: AsyncConfig) throws -> Future<Void> {
	guard let scopesStr = scopesStr else {
		throw InvalidArgumentError(message: "The --scopes option is required to get a Google token.")
	}
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	return googleConnector.connect(scope: Set(scopesStr.components(separatedBy: ",")), asyncConfig: asyncConfig)
	.then{ _ -> Future<Void> in
		print(googleConnector.token!)
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
}

private func getGitHubToken(gitHubConfig: GitHubServiceConfig, scopesStr: String?, asyncConfig: AsyncConfig) throws -> Future<Void> {
	guard scopesStr == nil else {
		throw InvalidArgumentError(message: "Scopes are not supported to retrieve a GitHub token.")
	}
	
	let gitHubConnector = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
	return gitHubConnector.connect(scope: (), asyncConfig: asyncConfig)
	.then{ _ -> Future<Void> in
		print(gitHubConnector.token!)
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
}
