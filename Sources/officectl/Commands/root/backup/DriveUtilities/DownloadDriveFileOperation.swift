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
	
	let state: DownloadDriveState
	
	let doc: GoogleDriveDoc
	
	private(set) var result = Result<GoogleDriveDoc, Error>.failure(OperationIsNotFinishedError())
	
	init(state s: DownloadDriveState, doc d: GoogleDriveDoc) {
		doc = d
		state = s
	}
	
	override func startBaseOperation(isRetry: Bool) {
		if let n = doc.name     { _ = try? state.logFile.logCSVLine([doc.id, "name", n]) }
		if let t = doc.mimeType { _ = try? state.logFile.logCSVLine([doc.id, "mime-type", t]) }
		if let o = doc.owners   { _ = try? state.logFile.logCSVLine([doc.id, "owners", o.map{ $0.emailAddress?.stringValue ?? "<unknown address>" }.joined(separator: ", ")]) }
		if let p = doc.parents  { _ = try? state.logFile.logCSVLine([doc.id, "parent_ids", p.joined(separator: ", ")]) }
		if let perms = doc.permissions {
			let encoder = JSONEncoder()
			for pjson in perms {
				guard let pstr = (try? encoder.encode(pjson)).flatMap({ String(data: $0, encoding: .utf8) }) else {
					_ = try? state.logFile.logCSVLine([doc.id, "permission_string_interpolated_because_json_encoding_failed", "\(pjson)"])
					continue
				}
				_ = try? state.logFile.logCSVLine([doc.id, "permission", pstr])
			}
		}
		
		let fileDownloadDestinationURL = self.state.allFilesDestinationBaseURL.appendingPathComponent(self.doc.id, isDirectory: false)
		
		var urlComponents = URLComponents(url: driveApiBaseURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(doc.id), resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [URLQueryItem(name: "alt", value: "media")]
		
		var urlRequest = URLRequest(url: urlComponents.url!)
		urlRequest.timeoutInterval = 24*3600
		
		_ = state.connector.connect(scope: driveROScope, eventLoop: state.eventLoop)
			.flatMap{ _ in self.state.connector.authenticate(request: urlRequest, eventLoop: self.state.eventLoop) }
			.flatMap{ urlRequestAuthResult -> EventLoopFuture<Void> in
				var downloadConfig = URLRequestOperation.Config(request: urlRequestAuthResult.result, session: nil)
				downloadConfig.destinationURL = fileDownloadDestinationURL
				downloadConfig.downloadBehavior = .overwriteDestination
				downloadConfig.acceptableStatusCodes = IndexSet(integersIn: 200..<300).union(IndexSet(integer: 403))
				
				let op = DriveUtils.rateLimitGoogleDriveAPIOperation(DownloadBinaryForDoc(config: downloadConfig), queue: DownloadDriveFileOperation.downloadBinaryQueue)
				return EventLoopFuture<Void>.future(from: op, on: self.state.eventLoop, queue: DownloadDriveFileOperation.downloadBinaryQueue, resultRetriever: { o in
					if let e = o.finalError {throw e}
					else                    {return ()}
				})
		}
		.flatMap{ _ in
			self.state.getPaths(objectId: self.doc.id, objectName: self.doc.name ?? self.doc.id, parentIds: self.doc.parents)
		}
		.flatMapThrowing{ paths in
			let fm = FileManager.default
			for p in paths {
				_ = try? self.state.logFile.logCSVLine([self.doc.id, "path", p])
				
				let destinationURL = URL(fileURLWithPath: p, isDirectory: true, relativeTo: self.state.driveDestinationBaseURL)
				let destinationURLFolder = destinationURL.deletingLastPathComponent()
				
				/* Remove previous file if applicable. */
				_ = try? fm.removeItem(at: destinationURL)
				
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
	
	private func succeedDownload() {
		state.status.syncQueue.sync{
			state.status[state.userAndDest.user].nFilesProcessed += 1
			state.status[state.userAndDest.user].nBytesProcessed += doc.size.flatMap{ Int($0) } ?? 0
		}
		baseOperationEnded()
	}
	
	private func failDownload(error: Error) {
		_ = try? state.logFile.logCSVLine([doc.id, "download_error", error.legibleLocalizedDescription])
		state.status.syncQueue.sync{ state.status[state.userAndDest.user].nFailures += 1 }
		result = .failure(error)
		baseOperationEnded()
	}
	
}
