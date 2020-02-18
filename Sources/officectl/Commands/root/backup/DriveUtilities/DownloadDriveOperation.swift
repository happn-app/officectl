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
	
	let state: DownloadDriveState
	
	let downloadFilesQueue: OperationQueue
	
	private(set) var error: Error? = OperationIsNotFinishedError()
	
	init(googleConnector: GoogleJWTConnector, eventLoop: EventLoop, status: DownloadDrivesStatusActivity, userAndDest: GoogleUserAndDest, filters: [String]?, eraseDownloadedFiles: Bool, downloadFilesQueue dfq: OperationQueue) throws {
		downloadFilesQueue = dfq
		
		let dateFormatter = ISO8601DateFormatter()
		dateFormatter.formatOptions = [.withFullDate, .withFullTime]
		dateFormatter.formatOptions = dateFormatter.formatOptions.subtracting([.withColonSeparatorInTime, .withColonSeparatorInTimeZone, .withDashSeparatorInDate])
		let dateStr = dateFormatter.string(from: Date())
		
		state = DownloadDriveState(
			connector: GoogleJWTConnector(from: googleConnector, userBehalf: userAndDest.user.primaryEmail.stringValue),
			eventLoop: eventLoop,
			status: status,
			logFile: try LogFile(url: userAndDest.downloadDestination.appendingPathComponent(" logs - \(dateStr).csv", isDirectory: false), csvHeader: ["File ID", "Key", "Value"]),
			filters: filters,
			eraseDownloadedFiles: eraseDownloadedFiles,
			userAndDest: userAndDest,
			driveDestinationBaseURL: userAndDest.downloadDestination.appendingPathComponent("Drive", isDirectory: true),
			allFilesDestinationBaseURL: userAndDest.downloadDestination.appendingPathComponent("AllFiles", isDirectory: true)
		)
		
		/* Getting or creating the destination folders if needed. */
		try FileManager.default.createDirectory(at: state.driveDestinationBaseURL, withIntermediateDirectories: true, attributes: nil)
		try FileManager.default.createDirectory(at: state.allFilesDestinationBaseURL, withIntermediateDirectories: true, attributes: nil)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		_ = state.connector.connect(scope: driveROScope, eventLoop: state.eventLoop)
		.flatMap{ _ in self.fetchAndDownloadDriveDocs(currentListOfFiles: [], nextPageToken: nil) }
		.flatMap{ futures in EventLoopFuture.whenAllComplete(futures, on: self.state.eventLoop) }
		.flatMapThrowing{ r -> Void in
			if r.first(where: { $0.failureValue != nil }) != nil {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "At least one file was not successfully downloaded from drive \(self.state.userAndDest.user.userId.stringValue); see the log file for more info."])
			}
			return ()
		}
		.flatMap{ _ -> EventLoopFuture<Void> in
			/* Archive backup if applicable. */
			guard let archiveURL = self.state.userAndDest.archiveDestination else {
				return self.state.eventLoop.future()
			}
			
			self.state.status.syncQueue.sync{
				self.state.status[self.state.userAndDest.user].archiving = true
			}
			
			/* Will create the enclosing folder if not already there (a bit of
			 * trivia: the the call don’t fail if the directory already exist). */
			_ = try? FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
			let op = TarOperation(
				sources: [self.state.userAndDest.downloadDestination.lastPathComponent],
				relativeTo: self.state.userAndDest.downloadDestination.deletingLastPathComponent(),
				destination: archiveURL,
				compress: true,
				deleteSourcesOnSuccess: true
			)
			return EventLoopFuture<Void>.future(from: op, on: self.state.eventLoop, resultRetriever: { op in
				if let e = op.tarError ?? op.sourceDeletionErrors.randomElement()?.value {
					throw e
				}
				return ()
			})
		}
		.always{ r in
			self.state.status.syncQueue.sync{
				self.state.status[self.state.userAndDest.user].finished = true
			}
			self.error = r.failureValue
			self.baseOperationEnded()
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private func fetchAndDownloadDriveDocs(currentListOfFiles: [EventLoopFuture<GoogleDriveDoc>], nextPageToken: String?) -> EventLoopFuture<[EventLoopFuture<GoogleDriveDoc>]> {
		var urlComponents = URLComponents(url: URL(string: "files", relativeTo: driveApiBaseURL)!, resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [URLQueryItem(name: "fields", value: "nextPageToken,files/*,files/permissions/*,files/permissions/permissionDetails/*,kind,incompleteSearch")]
		if let t = nextPageToken {urlComponents.queryItems!.append(URLQueryItem(name: "pageToken", value: t))}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = DriveUtils.rateLimitGoogleDriveAPIOperation(AuthenticatedJSONOperation<GoogleDriveFilesList>(url: urlComponents.url!, authenticator: state.connector.authenticate, decoder: decoder, retryInfoRecoveryHandler: DriveUtils.retryRecoveryHandler(_:sourceError:completionHandler:)))
		return state.connector.connect(scope: driveROScope, eventLoop: state.eventLoop)
		.flatMap{ _ in EventLoopFuture<GoogleDriveFilesList>.future(from: op, on: self.state.eventLoop) }
		.flatMap{ newFilesList in
			var newFullListOfFiles = currentListOfFiles
			if let files = newFilesList.files {
				var nBytesFound = 0
				var nBytesIgnored = 0
				var nFilesIgnored = 0
				for file in files {
					/* We keep the files (not folders) I own, or whose quota is
					 * either invalid (cannot be converted to an Int) or is > 0 */
					let mimeType = file.mimeType ?? ""
					let bytes = file.size.flatMap{ Int($0) } ?? 0
					let quota = file.quotaBytesUsed.flatMap({ Int($0) })
					let isFobiddenMimeType = mimeType.starts(with: "application/vnd.google-apps.")
					guard !isFobiddenMimeType && (file.ownedByMe || quota == nil || quota! > 0) else {
						nFilesIgnored += 1
						nBytesIgnored += bytes
						continue
					}
					
					nBytesFound += bytes
					
					let op = DownloadDriveFileOperation(state: self.state, doc: file)
					let f = EventLoopFuture<GoogleDriveDoc>.future(from: op, on: self.state.eventLoop, queue: self.downloadFilesQueue)
					newFullListOfFiles.append(f)
				}
				self.state.status.syncQueue.sync{
					self.state.status[self.state.userAndDest.user].nBytesToProcess += nBytesFound
					self.state.status[self.state.userAndDest.user].nFilesToProcess = newFullListOfFiles.count
					self.state.status[self.state.userAndDest.user].nBytesIgnored += nBytesIgnored
					self.state.status[self.state.userAndDest.user].nFilesIgnored += nFilesIgnored
				}
			}
			self.state.status.syncQueue.sync{
				self.state.status[self.state.userAndDest.user].foundAllFiles = newFilesList.nextPageToken == nil
			}
			if let t = newFilesList.nextPageToken {return self.fetchAndDownloadDriveDocs(currentListOfFiles: newFullListOfFiles, nextPageToken: t)}
			else                                  {return self.state.eventLoop.makeSucceededFuture(newFullListOfFiles)}
		}
	}
	
}
