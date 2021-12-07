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
	
	let filters: [String]?
	let skipOtherOwner: Bool
	let skipZeroQuotaFiles: Bool
	
	let eraseDownloadedFiles: Bool
	
	let userAndDest: GoogleUserAndDest
	let driveDestinationBaseURL: URL
	let allFilesDestinationBaseURL: URL
	
	init(connector c: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatusActivity, logFile lf: LogFile, filters f: [String]?, skipOtherOwner soo: Bool, skipZeroQuotaFiles szqf: Bool, eraseDownloadedFiles edf: Bool, userAndDest uad: GoogleUserAndDest, driveDestinationBaseURL ddbu: URL, allFilesDestinationBaseURL afdbu: URL) {
		connector = c
		eventLoop = el
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
	
	func getPaths(objectId: String, objectName: String, parentIds: [String]?) -> EventLoopFuture<[String]> {
		guard let parentIds = parentIds, !parentIds.isEmpty else {
			return eventLoop.future([deduplicatePath(originalPath: objectName, for: objectId)])
		}
		
		let futures = parentIds.map{ parentId -> EventLoopFuture<[String]> in
			let futureObject = pathsCacheQueue.sync{ () -> EventLoopFuture<[String]> in
				/* Do we already have the object future in the cache? */
				if let futureObject = pathsCache[parentId] {
					return futureObject
				} else {
					var urlComponents = URLComponents(url: URL(string: "files/" + parentId, relativeTo: driveApiBaseURL)!, resolvingAgainstBaseURL: true)!
					urlComponents.queryItems = [URLQueryItem(name: "fields", value: "id,name,parents,ownedByMe")]
					
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .customISO8601
					decoder.keyDecodingStrategy = .useDefaultKeys
					let op = DriveUtils.rateLimitGoogleDriveAPIOperation(AuthenticatedJSONOperation<GoogleDriveDoc>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder, retryInfoRecoveryHandler: DriveUtils.retryRecoveryHandler(_:sourceError:completionHandler:)))
					
					let connectionPromise = eventLoop.makePromise(of: Void.self)
					Task{
						do {
							try await connector.connect(scope: driveROScope)
							connectionPromise.completeWith(.success(()))
						} catch {
							connectionPromise.fail(error)
						}
					}
					let futureObject = connectionPromise.futureResult
						.flatMap{ _ in EventLoopFuture<GoogleDriveDoc>.future(from: op, on: self.eventLoop) }
						.flatMap{ doc in self.getPaths(objectId: doc.id, objectName: (doc.name ?? doc.id), parentIds: doc.parents) }
					
					pathsCache[parentId] = futureObject
					return futureObject
				}
			}
			
			return futureObject
				.map{ paths in return paths.map{ self.deduplicatePath(originalPath: ($0 as NSString).appendingPathComponent(objectName), for: objectId) } }
		}
		return EventLoopFuture<[String]>.whenAllSucceed(futures, on: eventLoop).map{ $0.flatMap{ $0 } }
	}
	
	private let pathsCacheQueue = DispatchQueue(label: "com.happn.officectl.downloaddrivepathscachequeue")
	private var pathsCache = [String: EventLoopFuture<[String]>]()
	private var knownPaths = Set<String>()
	
	private func deduplicatePath(originalPath: String, for objectId: String) -> String {
		pathsCacheQueue.sync{
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
				_ = try? logFile.logCSVLine([objectId, "duplicate_path_warning", "Path “\(originalPath)” already exist; renamed to “\(newPath)”"])
			}
			return newPath
		}
	}
	
}
