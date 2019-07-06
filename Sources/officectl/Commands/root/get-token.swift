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
	let officeKitConfig = try context.container.make(OfficectlConfig.self).officeKitConfig
	
	let scopes = f.getString(name: "scopes")
	let serviceId = f.getString(name: "service-id")
	let serviceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	
	let token: Future<String>
	if let googleConfig: GoogleServiceConfig = serviceConfig.unboxed() {
		token = try getGoogleToken(googleConfig: googleConfig, scopesStr: scopes, eventLoop: context.container.eventLoop)
		
	} else if let gitHubConfig: GitHubServiceConfig = serviceConfig.unboxed() {
		token = try getGitHubToken(gitHubConfig: gitHubConfig, scopesStr: scopes, eventLoop: context.container.eventLoop)
		
	} else {
		throw InvalidArgumentError(message: "Unsupported service to get a token from.")
	}
	
	return token.map{
		print("token: \($0)")
	}
}

private func getGoogleToken(googleConfig: GoogleServiceConfig, scopesStr: String?, eventLoop: EventLoop) throws -> Future<String> {
	guard let scopesStr = scopesStr else {
		throw InvalidArgumentError(message: "The --scopes option is required to get a Google token.")
	}
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	return googleConnector.connect(scope: Set(scopesStr.components(separatedBy: ",")), eventLoop: eventLoop)
	.map{ _ -> String in
		return googleConnector.token!
	}
}

private func getGitHubToken(gitHubConfig: GitHubServiceConfig, scopesStr: String?, eventLoop: EventLoop) throws -> Future<String> {
	guard scopesStr == nil else {
		throw InvalidArgumentError(message: "Scopes are not supported to retrieve a GitHub token.")
	}
	
	let gitHubConnector = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
	return gitHubConnector.connect(scope: (), eventLoop: eventLoop)
	.map{ _ -> String in
		return gitHubConnector.token!
	}
}
