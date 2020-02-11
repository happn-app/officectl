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

import GenericJSON
import Guaka
import NIO
import OfficeKit
import RetryingOperation
import URLRequestOperation
import Vapor



/* Should be namespaced, or private. */
let driveROScope = Set(arrayLiteral: "https://www.googleapis.com/auth/drive.readonly")
let driveApiBaseURL = URL(string: "https://www.googleapis.com/drive/v3/")!


func backupDrive(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let officeKitConfig = app.officeKitConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	let disableConsole = f.getBool(name: "no-interactive-console")!
	
	let serviceId = f.getString(name: "service-id")
	let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
	
	let downloadsDestinationFolder = URL(fileURLWithPath: f.getString(name: "downloads-destination-folder")!, isDirectory: true)
	
	let disabledUserSuffix = f.getString(name: "disabled-email-suffix")
	let usersFilter = (args.isEmpty ? nil : args)?.map{ EmailSrcAndDst(emailStr: $0, disabledUserSuffix: disabledUserSuffix, logger: app.logger) }
	
	let eraseDownloadedFiles = f.getBool(name: "erase-downloaded-files")!
	let skipIfArchiveFound = !f.getBool(name: "no-skip-if-archive-exists")!
	let archiveDestinationFolderStr = (f.getBool(name: "archive")! ? try nil2throw(f.getString(name: "archives-destination-folder")) : nil)
	let archiveDestinationFolder = archiveDestinationFolderStr.flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
	
	try app.auditLogger.log(action: "Backing up mails w/ service \(serviceId ?? "<inferred service>"), users filter \(usersFilter?.map{ $0.debugDescription }.joined(separator: ",") ?? "<no filter>"), \(archiveDestinationFolder != nil ? "w/": "w/o") archiving.", source: .cli)
	
	let downloadDriveStatus = DownloadDrivesStatusActivity()
	let consoleActivity = downloadDriveStatus.newActivity(for: context.console)
	if !disableConsole {consoleActivity.start()}
	
	let downloadFilesQueue = OperationQueue(name_OperationQueue: "Files Download Queue")
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	let f = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: eventLoop)
	.flatMap{ _ -> EventLoopFuture<[GoogleUserAndDest]> in
		GoogleUserAndDest.fetchListToBackup(
			googleConfig: googleConfig, googleConnector: googleConnector,
			usersFilter: usersFilter, disabledUserSuffix: disabledUserSuffix,
			downloadsDestinationFolder: downloadsDestinationFolder, archiveDestinationFolder: archiveDestinationFolder,
			skipIfArchiveFound: skipIfArchiveFound,
			console: context.console, eventLoop: eventLoop
		)
	}
	.flatMapThrowing{ filteredUsers -> EventLoopFuture<[GoogleUserAndDest]> in /* Backup given mails */
		downloadDriveStatus.initStatuses(users: filteredUsers.map{ $0.user })
		
		let operations = try filteredUsers.map{ try DownloadDriveOperation(googleConnector: googleConnector, eventLoop: eventLoop, status: downloadDriveStatus, userAndDest: $0, downloadFilesQueue: downloadFilesQueue) }
		return EventLoopFuture<GoogleUserAndDest>.executeAll(operations, on: eventLoop, resultRetriever: { (o: DownloadDriveOperation) -> GoogleUserAndDest in
			try throwIfError(o.error)
			return o.userAndDest
		})
		.flatMapThrowing{ downloadResults in
			assert(downloadResults.count == filteredUsers.count)
			let errors = downloadResults.enumerated().compactMap{ result in result.element.failureValue.flatMap{ (filteredUsers[result.offset], $0) } }
			guard errors.isEmpty else {
				/* Currently we stop everything if we got at least one error. */
				/* TODO: Properly report the error (say this user got an error, not
				 *       just here are the errors!) */
				throw ErrorCollection(errors.map{ $0.1 })
			}
			return filteredUsers
		}
	}
	.flatMap{ $0 }
	.transform(to: ())
	.always{ r in
		guard !disableConsole else {return}
		switch r {
		case .success: consoleActivity.succeed()
		case .failure: consoleActivity.fail()
		}
	}
	
	return f
}
