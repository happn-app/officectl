/*
 * DownloadDriveState.swift
 * officectl
 *
 * Created by François Lamboley on 2020/02/11.
 */

import Foundation

import NIO
import OfficeKit
import URLRequestOperation



actor DownloadDriveState {
	
	let connector: GoogleJWTConnector
	let status: DownloadDrivesStatusActivity
	let logFile: LogFile
	
	let filters: [String]?
	let skipOtherOwner: Bool
	let skipZeroQuotaFiles: Bool
	
	let eraseDownloadedFiles: Bool
	
	let userAndDest: GoogleUserAndDest
	let driveDestinationBaseURL: URL
	let allFilesDestinationBaseURL: URL
	
	init(connector c: GoogleJWTConnector, status s: DownloadDrivesStatusActivity, logFile lf: LogFile, filters f: [String]?, skipOtherOwner soo: Bool, skipZeroQuotaFiles szqf: Bool, eraseDownloadedFiles edf: Bool, userAndDest uad: GoogleUserAndDest, driveDestinationBaseURL ddbu: URL, allFilesDestinationBaseURL afdbu: URL) {
		connector = c
		status = s
		logFile = lf
		
		filters = f
		skipOtherOwner = soo
		skipZeroQuotaFiles = szqf
		
		eraseDownloadedFiles = edf
		
		userAndDest = uad
		driveDestinationBaseURL = ddbu
		allFilesDestinationBaseURL = afdbu
	}
	
	/* This shouldn’t be in a “state” object… */
	func getPaths(objectID: String, objectName: String, parentIDs: [String]?) async throws -> [String] {
		guard let parentIDs = parentIDs, !parentIDs.isEmpty else {
			return [deduplicatePath(originalPath: objectName, for: objectID)]
		}
		
		/* Not sure of the performance implications of using a task group instead of this directly.
		 * Anyway I don’t think doing this exactly is possible with a task group. */
		let tasks = parentIDs.map{ parentID -> Task<[String], Error> in
			let task = pathsCache[parentID] ?? Task{
				try await connector.connect(scope: driveROScope)
				
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .customISO8601
				let op = DriveUtils.rateLimitGoogleDriveAPIOperation(
					try URLRequestDataOperation<GoogleDriveDoc>.forAPIRequest(
						url: driveApiBaseURL.appending("files", parentID), urlParameters: ["fields": "id,name,parents,ownedByMe"],
						requestProcessors: [AuthRequestProcessor(connector)],
						retryableStatusCodes: [403],
						retryProviders: [RateLimitRetryProvider()]
					)
				)
				
				let doc = try await op.startAndGetResult().result
				return try await getPaths(objectID: doc.id, objectName: (doc.name ?? doc.id), parentIDs: doc.parents)
			}
			
			pathsCache[parentID] = task
			return Task{
				try await task.value.map{ self.deduplicatePath(originalPath: ($0 as NSString).appendingPathComponent(objectName), for: objectID) }
			}
		}
		var res = [String]()
		for task in tasks {res += try await task.value}
		return res
	}
	
	private var pathsCache = [String: Task<[String], Error>]()
	private var knownPaths = Set<String>()
	
	private func deduplicatePath(originalPath: String, for objectID: String) -> String {
		var i = 2
		var newPath = originalPath
		let pathExt = (originalPath as NSString).pathExtension
		let pathBase = (originalPath as NSString).deletingPathExtension
		while !knownPaths.insert(newPath).inserted {
			let newPathBase = pathBase + " " + String(i)
			newPath = (newPathBase as NSString).appendingPathExtension(pathExt) ?? newPathBase + "." + pathExt
			i += 1
		}
		if i > 2 {
			_ = try? logFile.logCSVLine([objectID, "duplicate_path_warning", "Path “\(originalPath)” already exist; renamed to “\(newPath)”"])
		}
		return newPath
	}
	
}
