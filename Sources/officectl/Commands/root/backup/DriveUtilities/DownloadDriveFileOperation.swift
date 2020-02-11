/*
 * DownloadDriveFileOperation.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import GenericJSON
import NIO
import OfficeKit
import RetryingOperation
import URLRequestOperation



class DownloadDriveFileOperation : RetryingOperation, HasResult {
	
	static let downloadBinaryQueue = OperationQueue(name_OperationQueue: "Download Binary Queue")
	
	typealias ResultType = GoogleDriveDoc
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatusActivity
	let logFile: LogFile
	
	let user: GoogleUser
	let driveDestinationBaseURL: URL
	let allFilesDestinationBaseURL: URL
	let doc: GoogleDriveDoc
	
	private(set) var result = Result<GoogleDriveDoc, Error>.failure(OperationIsNotFinishedError())
	
	init(googleConnector gc: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatusActivity, logFile lf: LogFile, user u: GoogleUser, allFilesDestinationBaseURL afdbu: URL, driveDestinationBaseURL ddbu: URL, doc d: GoogleDriveDoc) {
		doc = d
		user = u
		status = s
		logFile = lf
		connector = gc
		eventLoop = el
		driveDestinationBaseURL = ddbu
		allFilesDestinationBaseURL = afdbu
	}
	
	override func startBaseOperation(isRetry: Bool) {
		if let n = doc.name          { _ = try? logFile.logCSVLine([doc.id, "name", n]) }
		if let t = doc.mimeType      { _ = try? logFile.logCSVLine([doc.id, "mime-type", t]) }
		if let o = doc.owners        { _ = try? logFile.logCSVLine([doc.id, "owners", o.map{ $0.emailAddress?.stringValue ?? "<unknown address>" }.joined(separator: ", ")]) }
		if let p = doc.parents       { _ = try? logFile.logCSVLine([doc.id, "parent_ids", p.joined(separator: ", ")]) }
		if let p = doc.permissionIds { _ = try? logFile.logCSVLine([doc.id, "permission_ids", p.joined(separator: ", ")]) }
		
		let fileDownloadDestinationURL = self.allFilesDestinationBaseURL.appendingPathComponent(self.doc.id, isDirectory: false)
		
		var urlComponents = URLComponents(url: driveApiBaseURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(doc.id), resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [URLQueryItem(name: "alt", value: "media")]
		
		var urlRequest = URLRequest(url: urlComponents.url!)
		urlRequest.timeoutInterval = 24*3600
		
		_ = connector.connect(scope: driveROScope, eventLoop: eventLoop)
			.flatMap{ _ in self.connector.authenticate(request: urlRequest, eventLoop: self.eventLoop) }
			.flatMap{ urlRequestAuthResult -> EventLoopFuture<Void> in
				var downloadConfig = URLRequestOperation.Config(request: urlRequestAuthResult.result, session: nil)
				downloadConfig.destinationURL = fileDownloadDestinationURL
				downloadConfig.downloadBehavior = .overwriteDestination
				downloadConfig.acceptableStatusCodes = IndexSet(integersIn: 200..<300).union(IndexSet(integer: 403))
				
				let op = DriveUtils.rateLimitGoogleDriveAPIOperation(DownloadBinaryForDoc(config: downloadConfig), queue: DownloadDriveFileOperation.downloadBinaryQueue)
				return EventLoopFuture<Void>.future(from: op, on: self.eventLoop, queue: DownloadDriveFileOperation.downloadBinaryQueue, resultRetriever: { o in
					if let e = o.finalError {throw e}
					else                    {return ()}
				})
		}
		.flatMap{ _ in
			self.getPaths(currentPath: self.doc.name ?? self.doc.id, parentIds: self.doc.parents)
		}
		.flatMapThrowing{ paths in
			let fm = FileManager.default
			for p in paths {
				_ = try? self.logFile.logCSVLine([self.doc.id, "parent", p])
				
				let destinationURL = URL(fileURLWithPath: p, isDirectory: true, relativeTo: self.driveDestinationBaseURL)
				let destinationURLFolder = destinationURL.deletingLastPathComponent()
				try fm.createDirectory(at: destinationURLFolder, withIntermediateDirectories: true, attributes: nil)
				try fm.linkItem(at: fileDownloadDestinationURL, to: destinationURL)
			}
		}
		.always{ result in
			switch result {
			case .success:        self.succeedDownload()
			case .failure(let e): self.failDownload(error: e)
			}
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private class DownloadBinaryForDoc : URLRequestOperationWithRetryRecoveryHandler {
		
		override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
			if statusCode == 403 {
				/* If we have a 403, we check the content of the file for the error
				 * reported by google. Whatever the error, we will delete the file
				 * after checking and reporting the error. */
				defer {downloadedFileURL.flatMap{ _ = try? FileManager.default.removeItem(at: $0) }}
				
				if let data = downloadedFileURL.flatMap({ try? Data(contentsOf: $0) }) {
					let jsonDecoder = JSONDecoder()
					guard
						let json = try? jsonDecoder.decode(JSON.self, from: data),
						let _ = json["error"]?["errors"]?.arrayValue?.first(where: { $0["domain"]?.stringValue == "usageLimits" && $0["reason"]?.stringValue == "userRateLimitExceeded" })
					else {
						return completionHandler(.doNotRetry, currentURLRequest, InvalidArgumentError(message: "Got 403 w/ message from server: \(data.reduce("", { $0 + String(format: "%02x", $1) }))"))
					}
					return completionHandler(.retry(withDelay: 100, enableReachability: false, enableOtherRequestsObserver: false), currentURLRequest, nil)
				}
				return completionHandler(.doNotRetry, currentURLRequest, InvalidArgumentError(message: "403 from server"))
			}
			super.computeRetryInfo(sourceError: error, completionHandler: completionHandler)
		}
		
	}
	
	private static let objectsCacheQueue = DispatchQueue(label: "com.happn.officectl.downloaddriveobjectscachequeue")
	private static var objectsCache = [String: EventLoopFuture<GoogleDriveDoc>]()
	private static var knownPaths = Set<String>()
	
	private func getPaths(currentPath: String, parentIds: [String]?) -> EventLoopFuture<[String]> {
		guard let parentIds = parentIds, !parentIds.isEmpty else {return eventLoop.future([currentPath])}
		
		let futures = DownloadDriveFileOperation.objectsCacheQueue.sync{
			return parentIds.map{ parentId -> EventLoopFuture<[String]> in
				let futureObject: EventLoopFuture<GoogleDriveDoc>
				/* Do we already have the object future in the cache? */
				if let f = DownloadDriveFileOperation.objectsCache[parentId] {
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
	
	private func succeedDownload() {
		status.syncQueue.sync{
			status[user].nFilesProcessed += 1
			status[user].nBytesProcessed += doc.size.flatMap{ Int($0) } ?? 0
		}
		baseOperationEnded()
	}
	
	private func failDownload(error: Error) {
		_ = try? logFile.logCSVLine([doc.id, "download_error", error.legibleLocalizedDescription])
		status.syncQueue.sync{ status[user].nFailures += 1 }
		result = .failure(error)
		baseOperationEnded()
	}
	
}
