/*
 * drive.swift
 * officectl
 *
 * Created by François Lamboley on 09/01/2020.
 */

/* TODO: Use ncurses to draw the current download status of the drive.
 *       https://dev.iachieved.it/iachievedit/ncurses-with-swift-on-linux/ */
#if canImport(Darwin)
import Darwin.ncurses
#else
import CNCurses
#endif
import Foundation

import ArgumentParser
import GenericJSON
import NIO
import OfficeKit
import RetryingOperation
import URLRequestOperation
import Vapor



/* Should be namespaced, or private. */
let driveScope = Set(arrayLiteral: "https://www.googleapis.com/auth/drive")
let driveROScope = Set(arrayLiteral: "https://www.googleapis.com/auth/drive.readonly")
let driveApiBaseURL = URL(string: "https://www.googleapis.com/drive/v3/")!


struct BackupDriveCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "drive",
		abstract: "Backup the drive of the given emails (or all mails in the given service if none are specified) to a directory.",
		discussion: """
			The “data” files are copied as-is, the “cloud” files are converted to xlsx, pptx and docx. A document
			will be generated to summarize the sync, and list potential data losses (conversion is impossible, etc.)
			
			The “disabled-email-suffix” option exists too, just like for the backup mails action. See the doc of
			the action for more info.
			"""
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@OptionGroup()
	var backupOptions: BackupCommand.Options
	
	@ArgumentParser.Option(help: "The id of the Google service to use to do the backup. Required if there are more than one Google service in officectl conf, otherwise the only Google service is used.")
	var serviceId: String?
	
	@ArgumentParser.Option(help: "When downloading the drive, if the username of the email has the given suffix, the resulting destination will be the same email without the suffix in the username. The drives to backup given will be searched with and without the suffix.")
	var disabledEmailSuffix: String?
	
	@ArgumentParser.Flag(inversion: .prefixedNo, help: "Whether to remove the files from the drive after downloading them. If a file is shared it will be also removed! A log file will contain all the shared files that have been removed, with the list of people w/ access to the files.")
	var eraseDownloadedFiles: Bool
	
	@ArgumentParser.Option(help: "Only download files matching the given filters. The filters are applied on the full paths of the files. If any path matches (case-insensitive match), the file will be downloaded. The filter is NOT a regex; only a basic case-insensitive string match will be done, however if the filter starts with a ^ the filter will have to match the beginning of the path. It is thus impossible to specify a filter starting with “^”.")
	var pathFilters: [String]
	
	@ArgumentParser.Flag(inversion: .prefixedNo, help: "Do not download files not owned by the user, even if they take quota for the user.")
	var skipOtherOwner: Bool
	
	@ArgumentParser.Flag(inversion: .prefixedNo, help: "Skip files not taking any quota for the user.")
	var skipZeroQuotaFiles = true
	
	@ArgumentParser.Flag(inversion: .prefixedNo, help: "Whether to archive the backup (create a tar bz2 file and remove the directory).")
	var archive: Bool
	
	@ArgumentParser.Flag(inversion: .prefixedNo, help: "Ignored when not archiving. If the archive for an email already exists, skip the backup for this email. Otherwise, the existing archive will be overwritten.")
	var skipIfArchiveExists = true
	
	@ArgumentParser.Option(help: "The path in which the archives will be put. Defaults to pwd. Required iif archive is set.")
	var archivesDestinationFolder: String?
	
	@ArgumentParser.Argument()
	var arguments: [String]
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) async throws {
		URLRequestOperationConfig.logger = nil
		
		let app = context.application
		let officeKitConfig = app.officeKitConfig
		let opQ = try app.services.make(OperationQueue.self)
		
		let disableConsole = !globalOptions.interactiveConsole
		
		let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
		_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
		
		let downloadsDestinationFolder = URL(fileURLWithPath: backupOptions.downloadsDestinationFolder, isDirectory: true)
		
		let usersFilter = (arguments.isEmpty ? nil : arguments)?.map{ EmailSrcAndDst(emailStr: $0, disabledUserSuffix: disabledEmailSuffix, logger: app.logger) }
		
		let filters = pathFilters.map{ $0.lowercased() }
		
		let archivesDestinationFolder = archivesDestinationFolder
		let archivesDestinationFolderStr = (archive ? try nil2throw(archivesDestinationFolder) : nil)
		let archivesDestinationFolderURL = archivesDestinationFolderStr.flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
		
		try app.auditLogger.log(action: "Backing up mails w/ service \(serviceId ?? "<inferred service>"), users filter \(usersFilter?.map{ $0.debugDescription }.joined(separator: ",") ?? "<no filter>"), \(archivesDestinationFolderURL != nil ? "w/": "w/o") archiving.", source: .cli)
		
		let previousOfficeKitLogger = OfficeKitConfig.logger
		let downloadDriveStatus = DownloadDrivesStatusActivity()
		let consoleActivity = downloadDriveStatus.newActivity(for: context.console)
		if !disableConsole {
			OfficeKitConfig.logger = nil
			consoleActivity.start()
		}
		
		let res = await Result{
			let downloadFilesQueue = OperationQueue(name_OperationQueue: "Files Download Queue")
			
			let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
			try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
			
			let filteredUsers = try await GoogleUserAndDest.fetchListToBackup(
				googleConfig: googleConfig, googleConnector: googleConnector,
				usersFilter: usersFilter, disabledUserSuffix: disabledEmailSuffix,
				downloadsDestinationFolder: downloadsDestinationFolder, archiveDestinationFolder: archivesDestinationFolderURL,
				skipIfArchiveFound: skipIfArchiveExists,
				console: context.console, opQ: opQ
			)
			
			/* Backup given mails */
			await downloadDriveStatus.initStatuses(users: filteredUsers.map{ $0.user })
			
			let operations = try filteredUsers.map{ try DownloadDriveOperation(googleConnector: googleConnector, status: downloadDriveStatus, userAndDest: $0, filters: filters, skipOtherOwner: skipOtherOwner, skipZeroQuotaFiles: skipZeroQuotaFiles, eraseDownloadedFiles: eraseDownloadedFiles, downloadFilesQueue: downloadFilesQueue) }
			try await app.services.make(OperationQueue.self).addOperationsAndWait(operations)
			/* Currently we stop everything if we got at least one error. */
			/* TODO: Properly report the error (say this user got an error, not just here are the errors!) */
			try operations.forEach{ o in
				try throwIfError(o.error)
			}
		}
		
		if !disableConsole {
			switch res {
				case .success: consoleActivity.succeed()
				case .failure: consoleActivity.fail()
			}
			OfficeKitConfig.logger = previousOfficeKitLogger
		}
	}
	
}
