/*
 * DownloadDriveFileOperation.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import AsyncOperationResult
import GenericJSON
import NIO
import OfficeKit
import RetryingOperation
import URLRequestOperation



class DownloadDriveFileOperation : RetryingOperation, HasResult {
	
	static let downloadBinaryQueue = OperationQueue(name_OperationQueue: "Download Binary Queue")
	static let maximumNumberOfRetries = 7
	
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
		if let o = doc.owners   { _ = try? state.logFile.logCSVLine([doc.id, "owners", o.map{ $0.emailAddress?.rawValue ?? "<unknown address>" }.joined(separator: ", ")]) }
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
		let fileObjectURL = driveApiBaseURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(doc.id)
		
		let connectionPromise = state.eventLoop.makePromise(of: Void.self)
		Task{
			do {
				try await state.connector.connect(scope: driveROScope)
				connectionPromise.completeWith(.success(()))
			} catch {
				connectionPromise.fail(error)
			}
		}
		_ = connectionPromise.futureResult
		.flatMap{ _ in
			self.state.getPaths(objectId: self.doc.id, objectName: self.doc.name ?? self.doc.id, parentIds: self.doc.parents)
		}
		.flatMap{ paths -> EventLoopFuture<[String]> in
			/* First let’s make sure the paths match the given filters */
			if let filters = self.state.filters {
				var match = false
				for filter in filters where !match {
					if filter.starts(with: "^") {
						match = match || (paths.contains{ $0.lowercased().starts(with: filter.dropFirst()) })
					} else {
						match = match || (paths.contains{ $0.lowercased().contains(filter) })
					}
				}
				
				guard match else {
					return self.state.eventLoop.makeFailedFuture(FileSkippedError())
				}
			}
			
			var isDir = ObjCBool(true)
			guard !FileManager.default.fileExists(atPath: fileDownloadDestinationURL.path, isDirectory: &isDir) else {
				/* If the file exists and is not a directory we assume it has
				 * already been downloaded from the drive. We do not check
				 * whether it is out of date or not; we’re not a sync service,
				 * all we want mostly is being able to continue downloading if
				 * the process stopped for whatever reason.
				 * We still re-link the file even if it was already downloaded
				 * because we cannot be certain it has been linked without a db
				 * or an xattr on the files, which are neither solutions I want
				 * to implement. */
				guard !isDir.boolValue else {
					return self.state.eventLoop.makeFailedFuture(InvalidArgumentError(message: "A folder exists where a file would be downloaded (at \(fileDownloadDestinationURL.path)."))
				}
				return self.state.eventLoop.future(paths)
			}
			
			var urlComponents = URLComponents(url: fileObjectURL, resolvingAgainstBaseURL: true)!
			urlComponents.queryItems = [URLQueryItem(name: "alt", value: "media")]
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.timeoutInterval = 24*3600
			
			var downloadConfig = URLRequestOperation.Config(request: urlRequest, session: nil)
			downloadConfig.maximumNumberOfRetries = DownloadDriveFileOperation.maximumNumberOfRetries
			downloadConfig.destinationURL = fileDownloadDestinationURL
			downloadConfig.downloadBehavior = .failIfDestinationExists
			downloadConfig.acceptableStatusCodes = IndexSet(integersIn: 200..<300).union(IndexSet(integer: 403))
			
			let op = DriveUtils.rateLimitGoogleDriveAPIOperation(DownloadBinaryForDoc(config: downloadConfig, authenticator: self.state.connector.authenticate), queue: DownloadDriveFileOperation.downloadBinaryQueue)
			return EventLoopFuture<Void>.future(from: op, on: self.state.eventLoop, queue: DownloadDriveFileOperation.downloadBinaryQueue, resultRetriever: { o in
				if let e = o.finalError {throw e}
				else                    {return paths}
			})
		}
		.flatMapThrowing{ paths in
			let fm = FileManager.default
			for p in paths {
				_ = try? self.state.logFile.logCSVLine([self.doc.id, "path", p])
				
				let destinationURL = URL(fileURLWithPath: p, isDirectory: true, relativeTo: self.state.driveDestinationBaseURL)
				let destinationURLFolder = destinationURL.deletingLastPathComponent()
				
				/* Remove previous file if applicable. */
				var isDir = ObjCBool(true)
				guard !FileManager.default.fileExists(atPath: destinationURL.path, isDirectory: &isDir) || !isDir.boolValue else {
					throw InvalidArgumentError(message: "A folder exists where a link would be created (at \(destinationURL.path).")
				}
				_ = try? fm.removeItem(at: destinationURL)
				
				try fm.createDirectory(at: destinationURLFolder, withIntermediateDirectories: true, attributes: nil)
				try fm.linkItem(at: fileDownloadDestinationURL, to: destinationURL)
			}
		}
		.flatMap{ _ -> EventLoopFuture<Void> in
			/* Try and delete the downloaded file if needed */
			guard self.state.eraseDownloadedFiles else {
				return self.state.eventLoop.future()
			}
			
			let connectionPromise = self.state.eventLoop.makePromise(of: Void.self)
			Task{
				do {
					try await self.state.connector.connect(scope: driveScope)
					connectionPromise.completeWith(.success(()))
				} catch {
					connectionPromise.fail(error)
				}
			}
			return connectionPromise.futureResult
			.flatMap{ _ in
				var request = URLRequest(url: fileObjectURL)
				request.httpMethod = "DELETE"
				
				let requestOperationConfig = URLRequestOperation.Config(request: request, session: nil, maximumNumberOfRetries: DownloadDriveFileOperation.maximumNumberOfRetries, allowRetryingNonIdempotentRequests: true, acceptableStatusCodes: IndexSet(integersIn: 200..<300).union(IndexSet(integer: 403)))
				let op = DriveUtils.rateLimitGoogleDriveAPIOperation(DeleteFileURLRequestOperation(config: requestOperationConfig, authenticator: self.state.connector.authenticate))
				
				return EventLoopFuture<Void>.future(from: op, on: self.state.eventLoop, queue: DownloadDriveFileOperation.downloadBinaryQueue, resultRetriever: { o in
					if let e = o.finalError {throw InvalidArgumentError(message: "Cannot delete file; error: \(e)")}
					else                    {return ()}
				})
			}
		}
		.always{ result in
			switch result {
			case .success:                                    self.succeedDownload()
			case .failure(let e) where e is FileSkippedError: self.succeedSkippedDownload()
			case .failure(let e):                             self.failDownload(error: e)
			}
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private struct FileSkippedError : Error {}
	
	private class DownloadBinaryForDoc : URLRequestOperation {
		
		typealias Authenticator = (_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void
		let authenticator: Authenticator?
		
		init(config c: URLRequestOperation.Config, authenticator a: @escaping Authenticator) {
			authenticator = a
			super.init(config: c)
		}
		
		override func processURLRequestForRunning(_ originalRequest: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>) -> Void) {
			guard let authenticator = authenticator else {
				handler(.success(originalRequest))
				return
			}
			
			authenticator(originalRequest, { r, _ in handler(r.asyncOperationResult) })
		}
		
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
	
	private class DeleteFileURLRequestOperation : URLRequestOperationWithRetryRecoveryHandler {
		
		typealias Authenticator = (_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void
		let authenticator: Authenticator?
		
		init(config c: URLRequestOperation.Config, authenticator a: @escaping Authenticator) {
			authenticator = a
			super.init(config: c)
		}
		
		override func processURLRequestForRunning(_ originalRequest: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>) -> Void) {
			guard let authenticator = authenticator else {
				handler(.success(originalRequest))
				return
			}
			
			authenticator(originalRequest, { r, _ in handler(r.asyncOperationResult) })
		}
		
		override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
			if statusCode == 403 {
				return DriveUtils.retryRecoveryHandler(self, sourceError: InvalidArgumentError(message: "Got 403 when deleting file"), completionHandler: completionHandler)
			}
			super.computeRetryInfo(sourceError: error, completionHandler: completionHandler)
		}
		
	}
	
	private func succeedDownload() {
		state.status.syncQueue.sync{
			state.status[state.userAndDest.user].nFilesProcessed += 1
			state.status[state.userAndDest.user].nBytesProcessed += doc.size.flatMap{ Int($0) } ?? 0
		}
		result = .success(doc)
		baseOperationEnded()
	}
	
	private func succeedSkippedDownload() {
		state.status.syncQueue.sync{
			state.status[state.userAndDest.user].nFilesIgnored += 1
			state.status[state.userAndDest.user].nFilesToProcess -= 1
			state.status[state.userAndDest.user].nBytesIgnored -= doc.size.flatMap{ Int($0) } ?? 0
			state.status[state.userAndDest.user].nBytesToProcess -= doc.size.flatMap{ Int($0) } ?? 0
		}
		result = .success(doc)
		baseOperationEnded()
	}
	
	private func failDownload(error: Error) {
		_ = try? state.logFile.logCSVLine([doc.id, "download_error", error.legibleLocalizedDescription])
		state.status.syncQueue.sync{ state.status[state.userAndDest.user].nFailures += 1 }
		result = .failure(error)
		baseOperationEnded()
	}
	
}
