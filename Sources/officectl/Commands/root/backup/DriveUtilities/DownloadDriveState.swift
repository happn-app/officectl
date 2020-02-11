/*
 * DownloadDriveState.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import NIO
import OfficeKit



class DownloadDriveState {
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatusActivity
	let logFile: LogFile
	
	let userAndDest: GoogleUserAndDest
	let driveDestinationBaseURL: URL
	let allFilesDestinationBaseURL: URL
	
	init(connector c: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatusActivity, logFile lf: LogFile, userAndDest uad: GoogleUserAndDest, driveDestinationBaseURL ddbu: URL, allFilesDestinationBaseURL afdbu: URL) {
		connector = c
		eventLoop = el
		status = s
		logFile = lf
		userAndDest = uad
		driveDestinationBaseURL = ddbu
		allFilesDestinationBaseURL = afdbu
	}
	
	func getPaths(currentPath: String, parentIds: [String]?) -> EventLoopFuture<[String]> {
		guard let parentIds = parentIds, !parentIds.isEmpty else {return eventLoop.future([currentPath])}
		
		let futures = pathsCacheQueue.sync{
			return parentIds.map{ parentId -> EventLoopFuture<[String]> in
				let futureObject: EventLoopFuture<GoogleDriveDoc>
				/* Do we already have the object future in the cache? */
				if let f = pathsCache[parentId] {
					futureObject = f
				} else {
					var urlComponents = URLComponents(url: URL(string: "files/" + parentId, relativeTo: driveApiBaseURL)!, resolvingAgainstBaseURL: true)!
					urlComponents.queryItems = [URLQueryItem(name: "fields", value: "id,name,parents,ownedByMe")]
					
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .customISO8601
					decoder.keyDecodingStrategy = .useDefaultKeys
					let op = DriveUtils.rateLimitGoogleDriveAPIOperation(AuthenticatedJSONOperation<GoogleDriveDoc>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder, retryInfoRecoveryHandler: DriveUtils.retryRecoveryHandler(_:sourceError:completionHandler:)))
					futureObject = connector.connect(scope: driveROScope, eventLoop: eventLoop)
						.flatMap{ _ in EventLoopFuture<GoogleDriveDoc>.future(from: op, on: self.eventLoop) }
				}
				
				return futureObject.flatMap{ doc in
					let newPath = (doc.name ?? doc.id) + "/" + currentPath
					return self.getPaths(currentPath: newPath, parentIds: doc.parents)
				}
			}
		}
		return EventLoopFuture<[String]>.whenAllSucceed(futures, on: eventLoop).map{ $0.flatMap{ $0 } }
	}
//	_ = try? logFile.logCSVLine([newLink.fileId, "linking_warning", "Expected destination \(baseLink.destination.path) was already taken; renamed to \(newLink.destination.path)"])
	
	private let pathsCacheQueue = DispatchQueue(label: "com.happn.officectl.downloaddrivepathscachequeue")
	private var pathsCache = [String: EventLoopFuture<GoogleDriveDoc>]()
	private var knownPaths = Set<String>()
	
}
