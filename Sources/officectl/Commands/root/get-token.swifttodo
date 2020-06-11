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
import ServiceKit



func getToken(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let app = context.application
	let officeKitConfig = app.officeKitConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	let scopes = f.getString(name: "scopes")
	let serviceId = f.getString(name: "service-id")
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
