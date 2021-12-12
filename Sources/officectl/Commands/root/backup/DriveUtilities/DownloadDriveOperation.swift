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
import URLRequestOperation



class DownloadDriveOperation : RetryingOperation {
	
	let state: DownloadDriveState
	
	let downloadFilesQueue: OperationQueue
	
	private(set) var error: Error? = OperationIsNotFinishedError()
	
	init(googleConnector: GoogleJWTConnector, status: DownloadDrivesStatusActivity, userAndDest: GoogleUserAndDest, filters: [String]?, skipOtherOwner: Bool, skipZeroQuotaFiles: Bool, eraseDownloadedFiles: Bool, downloadFilesQueue dfq: OperationQueue) throws {
		downloadFilesQueue = dfq
		
		let dateFormatter = ISO8601DateFormatter()
		dateFormatter.formatOptions = [.withFullDate, .withFullTime]
		dateFormatter.formatOptions = dateFormatter.formatOptions.subtracting([.withColonSeparatorInTime, .withColonSeparatorInTimeZone, .withDashSeparatorInDate])
		let dateStr = dateFormatter.string(from: Date())
		
		state = DownloadDriveState(
			connector: GoogleJWTConnector(from: googleConnector, userBehalf: userAndDest.user.primaryEmail.rawValue),
			status: status,
			logFile: try LogFile(url: userAndDest.downloadDestination.appendingPathComponent(" logs - \(dateStr).csv", isDirectory: false), csvHeader: ["File ID", "Key", "Value"]),
			filters: filters,
			skipOtherOwner: skipOtherOwner,
			skipZeroQuotaFiles: skipZeroQuotaFiles,
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
		Task{
			error = await Result{
				try await state.connector.connect(scope: driveROScope)
				
				let tasks = try await fetchAndDownloadDriveDocs(currentListOfFiles: [], nextPageToken: nil)
				/* We wait for all tasks, and check if at least one got an error. */
				var foundError = false
				for task in tasks {
					if await task.result.failureValue != nil{
						foundError = true
					}
				}
				guard !foundError else {
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "At least one file was not successfully downloaded from drive \(state.userAndDest.user.userId.rawValue); see the log file for more info."])
				}
				
				/* Archive backup if applicable. */
				if let archiveURL = state.userAndDest.archiveDestination {
					await state.status.updateStatus(for: state.userAndDest.user, { $0.archiving = true })
					
					/* Will create the enclosing folder if not already there (a bit of trivia: the the call don’t fail if the directory already exist). */
					_ = try? FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
					let op = TarOperation(
						sources: [state.userAndDest.downloadDestination.lastPathComponent],
						relativeTo: state.userAndDest.downloadDestination.deletingLastPathComponent(),
						destination: archiveURL,
						compress: true,
						deleteSourcesOnSuccess: true
					)
					await op.startAndWait()
					if let e = op.tarError ?? op.sourceDeletionErrors.randomElement()?.value {
						throw e
					}
				}
			}.failureValue
			await state.status.updateStatus(for: state.userAndDest.user, { $0.finished = true })
			baseOperationEnded()
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private func fetchAndDownloadDriveDocs(currentListOfFiles: [Task<GoogleDriveDoc, Error>], nextPageToken: String?) async throws -> [Task<GoogleDriveDoc, Error>] {
		try await state.connector.connect(scope: driveROScope)
		
		struct RequestParams : Encodable {
			var fields: String = "nextPageToken,files/*,files/permissions/*,files/permissions/permissionDetails/*,kind,incompleteSearch"
			var pageToken: String?
		}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		let op = DriveUtils.rateLimitGoogleDriveAPIOperation(
			try URLRequestDataOperation<GoogleDriveFilesList>.forAPIRequest(
				url: driveApiBaseURL.appending("files"), urlParameters: RequestParams(pageToken: nextPageToken),
				decoders: [decoder],
				requestProcessors: [AuthRequestProcessor(state.connector)], retryProviders: [RateLimitRetryProvider()]
			)
		)
		
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		let newFilesList = try await op.startAndGetResult().result
		var newFullListOfFiles = currentListOfFiles
		if let files = newFilesList.files {
			var nBytesFound = 0
			var nBytesIgnored = 0
			var nFilesIgnored = 0
			for file in files {
				/* We keep the files (not folders) I own, or whose quota is either invalid (cannot be converted to an Int) or is > 0. */
				let mimeType = file.mimeType ?? ""
				let bytes = file.size.flatMap{ Int($0) } ?? 0
				let quota = file.quotaBytesUsed.flatMap({ Int($0) })
				let isSkippedBecauseOfOwner = state.skipOtherOwner && !(file.ownedByMe ?? true)
				let isFobiddenMimeType = mimeType.starts(with: "application/vnd.google-apps.")
				let isSkippedBecauseOfQuota = state.skipZeroQuotaFiles && quota != nil && quota! <= 0 /* If quota is nil we don’t skip; we consider we just do not have the quota but it might be non-zero */
				guard !isFobiddenMimeType && !isSkippedBecauseOfOwner && !isSkippedBecauseOfQuota else {
					nFilesIgnored += 1
					nBytesIgnored += bytes
					continue
				}
				
				nBytesFound += bytes
				
				let op = DownloadDriveFileOperation(state: state, doc: file)
				newFullListOfFiles.append(Task{ try await downloadFilesQueue.addOperationAndGetResult(op) })
			}
			
			await state.status.updateStatus(for: state.userAndDest.user, { [nBytesFound, newFullListOfFiles, nBytesIgnored, nFilesIgnored] userStatus in
				userStatus.nBytesToProcess += nBytesFound
				userStatus.nFilesToProcess = newFullListOfFiles.count
				userStatus.nBytesIgnored += nBytesIgnored
				userStatus.nFilesIgnored += nFilesIgnored
			})
		}
		
		await state.status.updateStatus(for: state.userAndDest.user, { userStatus in
			userStatus.foundAllFiles = (newFilesList.nextPageToken == nil)
		})
		
		if let t = newFilesList.nextPageToken {return try await fetchAndDownloadDriveDocs(currentListOfFiles: newFullListOfFiles, nextPageToken: t)}
		else                                  {return newFullListOfFiles}
	}
	
}
