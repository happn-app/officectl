/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit
import ServiceKit



struct GetTokenCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "get-token",
		abstract: "Get a token for a given service."
	)
	
	@ArgumentParser.Option(help: "A comma-separated list of scopes.")
	var scopes: String?
	
	@ArgumentParser.Option(name: .customLong("service-id"), help: "The ID of the service from which to retrieve the token.")
	var serviceID: String?
	
	@ArgumentParser.Option(help: "The user as whom to login as.")
	var userBehalf: String?
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let officeKitConfig = app.officeKitConfig
		let serviceConfig = try officeKitConfig.getServiceConfig(id: serviceID)
		
		try app.auditLogger.log(action: "Getting token for service \(serviceID ?? "<inferred service>") with scope \(scopes ?? "<no scope defined>").", source: .cli)
		
		let token: String
		if let googleConfig: GoogleServiceConfig = serviceConfig.unbox() {
			token = try await getGoogleToken(googleConfig: googleConfig, scopesStr: scopes, userBehalf: userBehalf)
			
		} else if let gitHubConfig: GitHubServiceConfig = serviceConfig.unbox() {
			token = try await getGitHubToken(gitHubConfig: gitHubConfig, scopesStr: scopes, userBehalf: userBehalf)
			
		} else {
			throw InvalidArgumentError(message: "Unsupported service to get a token from.")
		}
		
		context.console.output("token: \(token)", style: .plain)
	}
	
	private func getGoogleToken(googleConfig: GoogleServiceConfig, scopesStr: String?, userBehalf: String?) async throws -> String {
		guard let scopesStr = scopesStr else {
			throw InvalidArgumentError(message: "The --scopes option is required to get a Google token.")
		}
		
		var settings = googleConfig.connectorSettings
		settings.userBehalf = userBehalf
		let googleConnector = try GoogleJWTConnector(key: settings)
		try await googleConnector.connect(scope: Set(scopesStr.components(separatedBy: ",")))
		return await googleConnector.token!
	}
	
	private func getGitHubToken(gitHubConfig: GitHubServiceConfig, scopesStr: String?, userBehalf: String?) async throws -> String {
		guard scopesStr == nil else {
			throw InvalidArgumentError(message: "Scopes are not supported to retrieve a GitHub token.")
		}
		guard userBehalf == nil else {
			throw InvalidArgumentError(message: "Behalf is not supported to retrieve a GitHub token.")
		}
		
		let gitHubConnector = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
		try await gitHubConnector.connect(scope: ())
		return await gitHubConnector.token!
	}
	
}
