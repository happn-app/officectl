/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
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
	
	@ArgumentParser.Option(help: "The id of the service from which to retrieve the token.")
	var serviceId: String?
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		let app = context.application
		let officeKitConfig = app.officeKitConfig
		let eventLoop = try app.services.make(EventLoop.self)
		let serviceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
		
		try app.auditLogger.log(action: "Getting token for service \(serviceId ?? "<inferred service>") with scope \(scopes ?? "<no scope defined>").", source: .cli)
		
		let token: EventLoopFuture<String>
		if let googleConfig: GoogleServiceConfig = serviceConfig.unbox() {
			token = try getGoogleToken(googleConfig: googleConfig, scopesStr: scopes, on: eventLoop)
			
		} else if let gitHubConfig: GitHubServiceConfig = serviceConfig.unbox() {
			token = try getGitHubToken(gitHubConfig: gitHubConfig, scopesStr: scopes, on: eventLoop)
			
		} else {
			throw InvalidArgumentError(message: "Unsupported service to get a token from.")
		}
		
		return token.map{
			context.console.output("token: " + $0, style: .plain)
		}
	}
	
	private func getGoogleToken(googleConfig: GoogleServiceConfig, scopesStr: String?, on eventLoop: EventLoop) throws -> EventLoopFuture<String> {
		guard let scopesStr = scopesStr else {
			throw InvalidArgumentError(message: "The --scopes option is required to get a Google token.")
		}
		
		let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
		return googleConnector.connect(scope: Set(scopesStr.components(separatedBy: ",")), eventLoop: eventLoop)
			.map{ _ -> String in
				return googleConnector.token!
		}
	}
	
	private func getGitHubToken(gitHubConfig: GitHubServiceConfig, scopesStr: String?, on eventLoop: EventLoop) throws -> EventLoopFuture<String> {
		guard scopesStr == nil else {
			throw InvalidArgumentError(message: "Scopes are not supported to retrieve a GitHub token.")
		}
		
		let gitHubConnector = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
		return gitHubConnector.connect(scope: (), eventLoop: eventLoop)
			.map{ _ -> String in
				return gitHubConnector.token!
		}
	}
	
}
