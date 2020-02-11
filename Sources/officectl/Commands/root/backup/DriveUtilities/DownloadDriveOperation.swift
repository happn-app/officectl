/*
 * DownloadDriveOperation.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import NIO
import OfficeKit
import RetryingOperation



class DownloadDriveOperation : RetryingOperation {
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatusActivity
	let logFile: LogFile
	
	let userAndDest: GoogleUserAndDest
	let driveDestinationBaseURL: URL
	let allFilesDestinationBaseURL: URL
	
	let downloadFilesQueue: OperationQueue
	
	var error: Error? = OperationIsNotFinishedError()
	
	init(googleConnector gc: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatusActivity, userAndDest uad: GoogleUserAndDest, downloadFilesQueue dfq: OperationQueue) throws {
		status = s
		eventLoop = el
		userAndDest = uad
		downloadFilesQueue = dfq
		connector = GoogleJWTConnector(from: gc, userBehalf: userAndDest.user.primaryEmail.stringValue)
		
		logFile = try LogFile(url: userAndDest.downloadDestination.appendingPathComponent(" logs.csv", isDirectory: false), csvHeader: ["File ID", "Key", "Value"])
		
		/* Getting or creating the destination folders if needed. */
		driveDestinationBaseURL = userAndDest.downloadDestination.appendingPathComponent("Drive", isDirectory: true)
		allFilesDestinationBaseURL = userAndDest.downloadDestination.appendingPathComponent("AllFiles", isDirectory: true)
		try FileManager.default.createDirectory(at: driveDestinationBaseURL, withIntermediateDirectories: true, attributes: nil)
		try FileManager.default.createDirectory(at: allFilesDestinationBaseURL, withIntermediateDirectories: true, attributes: nil)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		_ = connector.connect(scope: driveROScope, eventLoop: eventLoop)
			.flatMap{ _ in self.fetchAndDownloadDriveDocs(connector: self.connector, currentListOfFiles: [], nextPageToken: nil) }
			.flatMap{ futures in EventLoopFuture.whenAllComplete(futures, on: self.eventLoop) }
			.always{ r in
				self.baseOperationEnded()
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private func fetchAndDownloadDriveDocs(connector: GoogleJWTConnector, currentListOfFiles: [EventLoopFuture<GoogleDriveDoc>], nextPageToken: String?) -> EventLoopFuture<[EventLoopFuture<GoogleDriveDoc>]> {
		var urlComponents = URLComponents(url: URL(string: "files", relativeTo: driveApiBaseURL)!, resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [URLQueryItem(name: "fields", value: "nextPageToken,files/*,kind,incompleteSearch")]
		if let t = nextPageToken {urlComponents.queryItems!.append(URLQueryItem(name: "pageToken", value: t))}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = DriveUtils.rateLimitGoogleDriveAPIOperation(AuthenticatedJSONOperation<GoogleDriveFilesList>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder, retryInfoRecoveryHandler: DriveUtils.retryRecoveryHandler(_:sourceError:completionHandler:)))
		return connector.connect(scope: driveROScope, eventLoop: eventLoop)
			.flatMap{ _ in EventLoopFuture<GoogleDriveFilesList>.future(from: op, on: self.eventLoop) }
			.flatMap{ newFilesList in
				var newFullListOfFiles = currentListOfFiles
				if let files = newFilesList.files {
					var nBytesFound = 0
					var nBytesIgnored = 0
					var nFilesIgnored = 0
					for file in files {
						/* We keep the files (not folders) I own, or whose quota is
						 * either invalid (cannot be converted to an Int) or is > 0 */
						let bytes = file.size.flatMap{ Int($0) } ?? 0
						let quota = file.quotaBytesUsed.flatMap({ Int($0) })
						guard file.mimeType != "application/vnd.google-apps.folder" && (file.ownedByMe || quota == nil || quota! > 0) else {
							nFilesIgnored += 1
							nBytesIgnored += bytes
							continue
						}
						
						nBytesFound += bytes
						
						let op = DownloadDriveFileOperation(googleConnector: connector, eventLoop: self.eventLoop, status: self.status, logFile: self.logFile, user: self.userAndDest.user, allFilesDestinationBaseURL: self.allFilesDestinationBaseURL, driveDestinationBaseURL: self.driveDestinationBaseURL, doc: file)
						let f = EventLoopFuture<GoogleDriveDoc>.future(from: op, on: self.eventLoop, queue: self.downloadFilesQueue)
						newFullListOfFiles.append(f)
					}
					self.status.syncQueue.sync{
						self.status[self.userAndDest.user].nBytesToProcess += nBytesFound
						self.status[self.userAndDest.user].nFilesToProcess = newFullListOfFiles.count
						self.status[self.userAndDest.user].nBytesIgnored += nBytesIgnored
						self.status[self.userAndDest.user].nFilesIgnored += nFilesIgnored
					}
				}
				self.status.syncQueue.sync{
					self.status[self.userAndDest.user].foundAllFiles = newFilesList.nextPageToken == nil
				}
				if let t = newFilesList.nextPageToken {return self.fetchAndDownloadDriveDocs(connector: connector, currentListOfFiles: newFullListOfFiles, nextPageToken: t)}
				else                                  {return self.eventLoop.makeSucceededFuture(newFullListOfFiles)}
		}
	}
	
}
