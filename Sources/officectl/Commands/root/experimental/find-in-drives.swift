/*
 * find-in-drives.swift
 * officectl
 *
 * Created by François Lamboley on 2020/06/26.
 */

import Foundation

import ArgumentParser
import CollectionConcurrencyKit
import Email
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
	
	@ArgumentParser.Option(help: "The ID of the Google service to use to do the search. Required if there are more than one Google service in officectl conf, otherwise the only Google service is used.")
	var serviceID: String?
	
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
		let opQ = try app.services.make(OperationQueue.self)
		
		let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceID)
		_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
		
		let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		let usersAndDest = try await GoogleUserAndDest.fetchListToBackup(
			googleConfig: googleConfig, googleConnector: googleConnector,
			usersFilter: nil, disabledUserSuffix: nil,
			downloadsDestinationFolder: URL(fileURLWithPath: "/tmp/not_used", isDirectory: true), archiveDestinationFolder: nil,
			skipIfArchiveFound: false, console: context.console, opQ: opQ
		)
		
		try await usersAndDest.concurrentForEach{ userAndDest in
			if let res = try await searchResults(for: userAndDest, searchedString: self.filename, mainConnector: googleConnector, opQ: opQ) {
				context.console.info("\(res)")
			}
		}
	}
	
	private func searchResults(for userAndDest: GoogleUserAndDest, searchedString: String, mainConnector: GoogleJWTConnector, opQ: OperationQueue) async throws -> String? {
		let connector = GoogleJWTConnector(from: mainConnector, userBehalf: userAndDest.user.primaryEmail.rawValue)
		try await connector.connect(scope: driveROScope)
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		
		let query = "name contains '\(searchedString.replacingOccurrences(of: #"'"#, with: #"\'"#))'"/* add " and trashed = true" to the query if needed */
		
		let op = try URLRequestDataOperation<GoogleDriveFilesList>.forAPIRequest(
			url: driveApiBaseURL.appending("files"), urlParameters: ["q": query],
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		let filesList = try await opQ.addOperationAndGetResult(op).result
		return (filesList.files?.map{ $0.id } ?? []).isEmpty ? nil : userAndDest.user.primaryEmail.rawValue
	}
	
}
