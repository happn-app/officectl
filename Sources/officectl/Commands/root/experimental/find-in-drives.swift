/*
 * find-in-drives.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2020.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



struct FindInDrivesCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "find-in-drives",
		abstract: "Find the given file or folder in all users drives."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Option(help: "The id of the Google service to use to do the search. Required if there are more than one Google service in officectl conf, otherwise the only Google service is used.")
	var serviceId: String?
	
	@ArgumentParser.Argument()
	var filename: String
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let officeKitConfig = app.officeKitConfig
		let eventLoop = try app.services.make(EventLoop.self)
		
		let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
		_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
		
		let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		let usersAndDest = try await GoogleUserAndDest.fetchListToBackup(
			googleConfig: googleConfig, googleConnector: googleConnector,
			usersFilter: nil, disabledUserSuffix: nil,
			downloadsDestinationFolder: URL(fileURLWithPath: "/tmp/not_used", isDirectory: true), archiveDestinationFolder: nil,
			skipIfArchiveFound: false, console: context.console, eventLoop: eventLoop
		)
		
		try await withThrowingTaskGroup(
			of: String?.self,
			returning: Void.self,
			body: { group in
				for userAndDest in usersAndDest {
					group.addTask{ try await searchResults(for: userAndDest, searchedString: self.filename, mainConnector: googleConnector, eventLoop: eventLoop) }
				}
				
				while let res = try await group.next() {
					if let res = res {
						context.console.info("\(res)")
					}
				}
			}
		)
	}
	
	private func searchResults(for userAndDest: GoogleUserAndDest, searchedString: String, mainConnector: GoogleJWTConnector, eventLoop: EventLoop) async throws -> String? {
		let connector = GoogleJWTConnector(from: mainConnector, userBehalf: userAndDest.user.primaryEmail.stringValue)
		try await connector.connect(scope: driveROScope)
		
		var urlComponents = URLComponents(url: driveApiBaseURL.appendingPathComponent("files", isDirectory: false), resolvingAgainstBaseURL: false)!
		urlComponents.queryItems = (urlComponents.queryItems ?? []) + [
			URLQueryItem(name: "q", value: "name contains '\(searchedString.replacingOccurrences(of: #"'"#, with: #"\'"#))'") /* add " and trashed = true" to the query if needed */
		]
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<GoogleDriveFilesList>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		let filesList = try await EventLoopFuture<GoogleDriveFilesList>.future(from: op, on: eventLoop).get()
		return (filesList.files?.map{ $0.id } ?? []).isEmpty ? nil : userAndDest.user.primaryEmail.stringValue
	}
	
}
