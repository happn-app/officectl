/*
 * DownloadDriveFileOperation.swift
 * officectl
 *
 * Created by François Lamboley on 2020/02/11.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import GenericJSON
import HasResult
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
		Task{
			let result = await Result{
				let fm = FileManager.default
				if let n = doc.name     {_ = try? state.logFile.logCSVLine([doc.id, "name", n])}
				if let t = doc.mimeType {_ = try? state.logFile.logCSVLine([doc.id, "mime-type", t])}
				if let o = doc.owners   {_ = try? state.logFile.logCSVLine([doc.id, "owners", o.map{ $0.emailAddress?.rawValue ?? "<unknown address>" }.joined(separator: ", ")])}
				if let p = doc.parents  {_ = try? state.logFile.logCSVLine([doc.id, "parent_ids", p.joined(separator: ", ")])}
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
				
				let fileDownloadDestinationURL = state.allFilesDestinationBaseURL.appendingPathComponent(doc.id, isDirectory: false)
				let fileObjectURL = driveApiBaseURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(doc.id)
				
				try await state.connector.connect(scope: driveROScope)
				
				let paths = try await state.getPaths(objectId: doc.id, objectName: doc.name ?? doc.id, parentIds: doc.parents)
				
				/* First let’s make sure the paths match the given filters. */
				if let filters = state.filters {
					var match = false
					for filter in filters where !match {
						guard !filter.isEmpty else {match = true; continue}
						if filter.starts(with: "^") {match = match || (paths.contains{ $0.lowercased().starts(with: filter.dropFirst()) })}
						else                        {match = match || (paths.contains{ $0.lowercased().contains(filter) })}
					}
					
					guard match else {
						throw FileSkippedError()
					}
				}
				
				var isDir = ObjCBool(true)
				if fm.fileExists(atPath: fileDownloadDestinationURL.path, isDirectory: &isDir) {
					/* If the file exists and is not a directory we assume it has already been downloaded from the drive.
					 * We do not check whether it is out of date or not; we’re not a sync service,
					 * all we want mostly is being able to continue downloading if the process stopped for whatever reason.
					 * We still re-link the file even if it was already downloaded because we cannot be certain it has been linked without a db or an xattr on the files,
					 * which are neither solutions I want to implement. */
					guard !isDir.boolValue else {
						throw InvalidArgumentError(message: "A folder exists where a file would be downloaded (at \(fileDownloadDestinationURL.path).")
					}
				} else {
					let urlRequest = URLRequest(url: try fileObjectURL.appendingQueryParameters(from: ["alt": "media"]), timeoutInterval: 24*3600)
					let op = DriveUtils.rateLimitGoogleDriveAPIOperation(
						URLRequestDownloadOperation(
							request: urlRequest,
							requestProcessors: [AuthRequestProcessor(state.connector)],
							urlResponseValidators: [HTTPStatusCodeURLResponseValidator(expectedCodes: Set(200..<300).union([403]))],
							resultProcessor: DownloadBinaryForDocResultProcessor()
								.flatMap(URLMoveResultProcessor(
									destinationURL: fileDownloadDestinationURL,
									moveBehavior: .failIfDestinationExists
								)),
							retryProviders: [RateLimitRetryProvider(maxRetries: DownloadDriveFileOperation.maximumNumberOfRetries)]
						)
					)
					_ = try await DownloadDriveFileOperation.downloadBinaryQueue.addOperationAndGetResult(op)
				}
				
				for p in paths {
					_ = try? self.state.logFile.logCSVLine([self.doc.id, "path", p])
					
					let destinationURL = URL(fileURLWithPath: p, isDirectory: true, relativeTo: self.state.driveDestinationBaseURL)
					let destinationURLFolder = destinationURL.deletingLastPathComponent()
					
					/* Remove previous file if applicable. */
					var isDir = ObjCBool(true)
					guard !fm.fileExists(atPath: destinationURL.path, isDirectory: &isDir) || !isDir.boolValue else {
						throw InvalidArgumentError(message: "A folder exists where a link would be created (at \(destinationURL.path).")
					}
					_ = try? fm.removeItem(at: destinationURL)
					
					try fm.createDirectory(at: destinationURLFolder, withIntermediateDirectories: true, attributes: nil)
					try fm.linkItem(at: fileDownloadDestinationURL, to: destinationURL)
				}
				
				/* Try and delete the downloaded file if needed. */
				guard state.eraseDownloadedFiles else {
					return
				}
				
				try await state.connector.connect(scope: driveScope)
				
				var request = URLRequest(url: fileObjectURL)
				request.httpMethod = "DELETE"
				let op = DriveUtils.rateLimitGoogleDriveAPIOperation(
					URLRequestDataOperation<Data>(
						request: request,
						requestProcessors: [AuthRequestProcessor(state.connector)],
						urlResponseValidators: [HTTPStatusCodeURLResponseValidator()],
						resultProcessor: .identity(),
						retryProviders: [
							UnretriedErrorsRetryProvider.forWhitelistedStatusCodes([403]),
							NetworkErrorRetryProvider(
								maximumNumberOfRetries: DownloadDriveFileOperation.maximumNumberOfRetries,
								alsoRetryNonIdempotentRequests: true,
								allowOtherSuccessObserver: false,
								allowReachabilityObserver: false
							)
						]
					)
				)
				_ = try await DownloadDriveFileOperation.downloadBinaryQueue.addOperationAndGetResult(op)
			}
			switch result {
				case .success:                                    await succeedDownload()
				case .failure(let e) where e is FileSkippedError: await succeedSkippedDownload()
				case .failure(let e):                             await failDownload(error: e)
			}
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private struct FileSkippedError : Error {}
	
	private struct DownloadBinaryForDocResultProcessor : ResultProcessor {
		
		public typealias SourceType = URL
		public typealias ResultType = URL
		
		func transform(source: URL, urlResponse: URLResponse, handler: @escaping (Result<URL, Error>) -> Void) {
			handler(Result{
				if (urlResponse as? HTTPURLResponse)?.statusCode == 403 {
					let data = try Data(contentsOf: source)
					throw URLRequestOperationError.UnexpectedStatusCode(expected: Set(200..<400), actual: 403, httpBody: data)
				}
				return source
			})
		}
		
	}
	
	private func succeedDownload() async {
		await state.status.updateStatus(for: state.userAndDest.user, { userStatus in
			userStatus.nFilesSucceeded += 1
			userStatus.nBytesSucceeded += doc.size.flatMap{ Int($0) } ?? 0
		})
		result = .success(doc)
		baseOperationEnded()
	}
	
	private func succeedSkippedDownload() async {
		await state.status.updateStatus(for: state.userAndDest.user, { userStatus in
			userStatus.nFilesIgnored += 1
			userStatus.nFilesToProcess -= 1
			userStatus.nBytesIgnored += doc.size.flatMap{ Int($0) } ?? 0
			userStatus.nBytesToProcess -= doc.size.flatMap{ Int($0) } ?? 0
		})
		result = .success(doc)
		baseOperationEnded()
	}
	
	private func failDownload(error: Error) async {
		_ = try? state.logFile.logCSVLine([doc.id, "download_error", error.legibleLocalizedDescription])
		await state.status.updateStatus(for: state.userAndDest.user, { userStatus in
			userStatus.nFilesFailed += 1
			userStatus.nBytesFailed += doc.size.flatMap{ Int($0) } ?? 0
		})
		result = .failure(error)
		baseOperationEnded()
	}
	
}
