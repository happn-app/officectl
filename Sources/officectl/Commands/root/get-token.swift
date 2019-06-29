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
	let officeKitServiceProvider = try context.container.make(OfficeKitServiceProvider.self)
	
	let scopes = f.getString(name: "scopes")
	let serviceId = try nil2throw(f.getString(name: "service-id"), "service-id")
	let directoryService = try officeKitServiceProvider.getDirectoryService(id: serviceId, container: context.container)
	
	if let googleService: GoogleService = directoryService.unwrapped() {
		return try getGoogleToken(googleService: googleService, scopesStr: scopes, asyncConfig: asyncConfig)
	}
	if let gitHubService: GitHubService = directoryService.unwrapped() {
		return try getGitHubToken(gitHubService: gitHubService, scopesStr: scopes, asyncConfig: asyncConfig)
	}
	
	throw InvalidArgumentError(message: "Unsupported service to get a token from.")
}

private func getGoogleToken(googleService: GoogleService, scopesStr: String?, asyncConfig: AsyncConfig) throws -> Future<Void> {
	guard let scopesStr = scopesStr else {
		throw InvalidArgumentError(message: "The --scopes option is required to get a Google token.")
	}
	
	let googleConnector = try GoogleJWTConnector(key: googleService.serviceConfig.connectorSettings)
	return googleConnector.connect(scope: Set(scopesStr.components(separatedBy: ",")), asyncConfig: asyncConfig)
	.then{ _ -> Future<Void> in
		print(googleConnector.token!)
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
}

private func getGitHubToken(gitHubService: GitHubService, scopesStr: String?, asyncConfig: AsyncConfig) throws -> Future<Void> {
	guard scopesStr == nil else {
		throw InvalidArgumentError(message: "Scopes are not supported to retrieve a GitHub token.")
	}
	
	let gitHubConnector = try GitHubJWTConnector(key: gitHubService.serviceConfig.connectorSettings)
	return gitHubConnector.connect(scope: (), asyncConfig: asyncConfig)
	.then{ _ -> Future<Void> in
		print(gitHubConnector.token!)
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
}
