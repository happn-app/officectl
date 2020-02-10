/*
 * drive.swift
 * officectl
 *
 * Created by François Lamboley on 09/01/2020.
 */

/* TODO: Use ncurses to draw the current download status of the drive.
 *       https://dev.iachieved.it/iachievedit/ncurses-with-swift-on-linux/ */
#if canImport(Darwin)
	import Darwin.ncurses
#else
	import CNCurses
#endif
import Foundation

import GenericJSON
import Guaka
import NIO
import OfficeKit
import RetryingOperation
import URLRequestOperation
import Vapor



private let csvSep = ","
private let driveROScope = Set(arrayLiteral: "https://www.googleapis.com/auth/drive.readonly")
private let driveApiBaseURL = URL(string: "https://www.googleapis.com/drive/v3/")!


func backupDrive(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let officeKitConfig = app.officeKitConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	let disableConsole = f.getBool(name: "no-interactive-console")!
	
	let serviceId = f.getString(name: "service-id")
	let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
	
	let downloadsDestinationFolder = URL(fileURLWithPath: f.getString(name: "downloads-destination-folder")!, isDirectory: true)
	
	let disabledUserSuffix = f.getString(name: "disabled-email-suffix")
	let usersFilter = (args.isEmpty ? nil : args)?.map{ EmailSrcAndDst(emailStr: $0, disabledUserSuffix: disabledUserSuffix, logger: app.logger) }
	
	let eraseDownloadedFiles = f.getBool(name: "erase-downloaded-files")!
	let skipIfArchiveFound = !f.getBool(name: "no-skip-if-archive-exists")!
	let archiveDestinationFolderStr = (f.getBool(name: "archive")! ? try nil2throw(f.getString(name: "archives-destination-folder")) : nil)
	let archiveDestinationFolder = archiveDestinationFolderStr.flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
	
	try app.auditLogger.log(action: "Backing up mails w/ service \(serviceId ?? "<inferred service>"), users filter \(usersFilter?.map{ $0.debugDescription }.joined(separator: ",") ?? "<no filter>"), \(archiveDestinationFolder != nil ? "w/": "w/o") archiving.", source: .cli)
	
	let downloadDriveStatus = DownloadDrivesStatus()
	let consoleActivity = downloadDriveStatus.newActivity(for: context.console)
	if !disableConsole {consoleActivity.start()}
	
	let downloadFilesQueue = OperationQueue(name_OperationQueue: "Files Download Queue")
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	let f = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: eventLoop)
	.flatMap{ _ -> EventLoopFuture<[GoogleUserAndDest]> in
		GoogleUserAndDest.fetchListToBackup(
			googleConfig: googleConfig, googleConnector: googleConnector,
			usersFilter: usersFilter, disabledUserSuffix: disabledUserSuffix,
			downloadsDestinationFolder: downloadsDestinationFolder, archiveDestinationFolder: archiveDestinationFolder,
			skipIfArchiveFound: skipIfArchiveFound,
			console: context.console, eventLoop: eventLoop
		)
	}
	.flatMapThrowing{ filteredUsers -> EventLoopFuture<[GoogleUserAndDest]> in /* Backup given mails */
		downloadDriveStatus.initStatuses(users: filteredUsers.map{ $0.user })
		
		let operations = try filteredUsers.map{ try DownloadDriveOperation(googleConnector: googleConnector, eventLoop: eventLoop, status: downloadDriveStatus, userAndDest: $0, downloadFilesQueue: downloadFilesQueue) }
		return EventLoopFuture<GoogleUserAndDest>.executeAll(operations, on: eventLoop, resultRetriever: { (o: DownloadDriveOperation) -> GoogleUserAndDest in
			try throwIfError(o.error)
			return o.userAndDest
		})
		.flatMapThrowing{ downloadResults in
			assert(downloadResults.count == filteredUsers.count)
			let errors = downloadResults.enumerated().compactMap{ result in result.element.failureValue.flatMap{ (filteredUsers[result.offset], $0) } }
			guard errors.isEmpty else {
				/* Currently we stop everything if we got at least one error. */
				/* TODO: Properly report the error (say this user got an error, not
				 *       just here are the errors!) */
				throw ErrorCollection(errors.map{ $0.1 })
			}
			return filteredUsers
		}
	}
	.flatMap{ $0 }
	.transform(to: ())
	.always{ r in
		guard !disableConsole else {return}
		switch r {
		case .success: consoleActivity.succeed()
		case .failure: consoleActivity.fail()
		}
	}
	
	return f
}

private func retryRecoveryHandler(_ operation: URLRequestOperationWithRetryRecoveryHandler, sourceError error: Error, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
	let jsonDecoder = JSONDecoder()
	guard
		let data = operation.fetchedData,
		let json = try? jsonDecoder.decode(JSON.self, from: data),
		let _ = json["error"]?["errors"]?.arrayValue?.first(where: { $0["domain"]?.stringValue == "usageLimits" && $0["reason"]?.stringValue == "userRateLimitExceeded" })
	else {
		return completionHandler(.doNotRetry, operation.currentURLRequest, error)
	}
	completionHandler(.retry(withDelay: 100, enableReachability: false, enableOtherRequestsObserver: false), operation.currentURLRequest, nil)
}

private func rateLimitGoogleDriveAPIOperation<T : Operation>(_ operation: T, queue: OperationQueue = OfficeKit.defaultOperationQueueForFutureSupport) -> T {
	let dateComponents = DateComponents(hour: nil, minute: nil, second: 0, nanosecond: 0)
	var calendar = Calendar(identifier: .gregorian)
	calendar.timeZone = TimeZone(abbreviation: "PST")!
	
	let rateLimitOperation = RateLimiterOperation(id: "google_drive_limits", limits: [
		RateLimiterOperation.Limit(maxCount: 10,            time: .duration(1)), /* Not officially in the list of quota, but the word of the street is this exists… */
		RateLimiterOperation.Limit(maxCount: 1_000,         time: .duration(100)),
		RateLimiterOperation.Limit(maxCount: 1_000_000_000, time: .resetAtDateComponents(dateComponents, calendar: calendar))
	])
	
	operation.addDependency(rateLimitOperation)
	queue.addOperation(rateLimitOperation)
	return operation
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


/* ****************************************** */

private class DownloadDriveOperation : RetryingOperation {
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatus
	let logFile: LogFile
	
	let userAndDest: GoogleUserAndDest
	let allFilesDestinationBaseURL: URL
	
	let downloadFilesQueue: OperationQueue
	
	var error: Error? = OperationIsNotFinishedError()
	
	init(googleConnector gc: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatus, userAndDest uad: GoogleUserAndDest, downloadFilesQueue dfq: OperationQueue) throws {
		status = s
		eventLoop = el
		userAndDest = uad
		downloadFilesQueue = dfq
		connector = GoogleJWTConnector(from: gc, userBehalf: userAndDest.user.primaryEmail.stringValue)
		
		logFile = try LogFile(url: userAndDest.downloadDestination.appendingPathComponent(" logs.csv", isDirectory: false), csvHeader: ["File ID", "Key", "Value"])
		
		/* Getting or creating the AllFiles destination folder if needed. */
		var isDir: ObjCBool = false
		allFilesDestinationBaseURL = userAndDest.downloadDestination.appendingPathComponent("AllFiles", isDirectory: true)
		if !FileManager.default.fileExists(atPath: allFilesDestinationBaseURL.path, isDirectory: &isDir) {
			/* The folder does not exist, let’s create it. */
			try FileManager.default.createDirectory(at: allFilesDestinationBaseURL, withIntermediateDirectories: true, attributes: nil)
		} else {
			/* There is a file or folder at the destination; let’s make sure it is
			 * a folder.*/
			guard isDir.boolValue else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create the destination folder"])
			}
		}
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
		let op = rateLimitGoogleDriveAPIOperation(AuthenticatedJSONOperation<GoogleDriveFilesList>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder, retryInfoRecoveryHandler: retryRecoveryHandler(_:sourceError:completionHandler:)))
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
					
					let op = DownloadFileFromDriveOperation(googleConnector: connector, eventLoop: self.eventLoop, status: self.status, logFile: self.logFile, userAndDest: self.userAndDest, allFilesDestinationBaseURL: self.allFilesDestinationBaseURL, doc: file)
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


/* ****************************************** */

private class DownloadFileFromDriveOperation : RetryingOperation, HasResult {
	
	typealias ResultType = GoogleDriveDoc
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatus
	let logFile: LogFile
	
	let userAndDest: GoogleUserAndDest
	let allFilesDestinationBaseURL: URL
	let doc: GoogleDriveDoc
	
	var result = Result<GoogleDriveDoc, Error>.failure(OperationIsNotFinishedError())
	
	init(googleConnector gc: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatus, logFile lf: LogFile, userAndDest uad: GoogleUserAndDest, allFilesDestinationBaseURL afdbu: URL, doc d: GoogleDriveDoc) {
		doc = d
		status = s
		logFile = lf
		connector = gc
		eventLoop = el
		userAndDest = uad
		allFilesDestinationBaseURL = afdbu
	}
	
	override func startBaseOperation(isRetry: Bool) {
		if let n = doc.name          { _ = try? logFile.logCSVLine([doc.id, "name", n]) }
		if let t = doc.mimeType      { _ = try? logFile.logCSVLine([doc.id, "mime-type", t]) }
		if let o = doc.owners        { _ = try? logFile.logCSVLine([doc.id, "owners", o.map{ $0.emailAddress?.stringValue ?? "<unknown address>" }.joined(separator: ", ")]) }
		if let p = doc.parents       { _ = try? logFile.logCSVLine([doc.id, "parent_ids", p.joined(separator: ", ")]) }
		if let p = doc.permissionIds { _ = try? logFile.logCSVLine([doc.id, "permission_ids", p.joined(separator: ", ")]) }
		
		var urlComponents = URLComponents(url: driveApiBaseURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(doc.id), resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [URLQueryItem(name: "alt", value: "media")]
		
		var urlRequest = URLRequest(url: urlComponents.url!)
		urlRequest.timeoutInterval = 24*3600
		
		_ = connector.connect(scope: driveROScope, eventLoop: eventLoop)
		.flatMap{ _ in self.connector.authenticate(request: urlRequest, eventLoop: self.eventLoop) }
		.flatMap{ urlRequestAuthResult -> EventLoopFuture<Void> in
			let fileDownloadDestinationURL = self.allFilesDestinationBaseURL.appendingPathComponent(self.doc.id, isDirectory: false)
			var downloadConfig = URLRequestOperation.Config(request: urlRequestAuthResult.result, session: nil)
			downloadConfig.destinationURL = fileDownloadDestinationURL
			downloadConfig.downloadBehavior = .overwriteDestination
			downloadConfig.acceptableStatusCodes = IndexSet(integersIn: 200..<300).union(IndexSet(integer: 403))
			
			let op = rateLimitGoogleDriveAPIOperation(DownloadBinaryForDoc(config: downloadConfig))
			return EventLoopFuture<Void>.future(from: op, on: self.eventLoop, resultRetriever: { o in
				if let e = o.finalError {throw e}
				else                    {return ()}
			})
		}
		.flatMap{ _ in
			self.getPaths(currentPath: self.doc.name ?? self.doc.id, parentIds: self.doc.parents)
		}
		.always{ result in
			_ = try? self.logFile.logCSVLine([self.doc.id, "parents", result.successValue?.joined(separator: ",") ?? "<unknown>"])
			switch result {
			case .success:        self.succeedDownload()
			case .failure(let e): self.failDownload(error: e)
			}
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private static let objectsCacheQueue = DispatchQueue(label: "com.happn.officectl.downloaddriveobjectscachequeue")
	private static var objectsCache = [String: EventLoopFuture<GoogleDriveDoc>]()
	
	private func getPaths(currentPath: String, parentIds: [String]?) -> EventLoopFuture<[String]> {
		guard let parentIds = parentIds, !parentIds.isEmpty else {return eventLoop.future([currentPath])}
		
		let futures = DownloadFileFromDriveOperation.objectsCacheQueue.sync{
			return parentIds.map{ parentId -> EventLoopFuture<[String]> in
				let futureObject: EventLoopFuture<GoogleDriveDoc>
				/* Do we already have the object future in the cache? */
				if let f = DownloadFileFromDriveOperation.objectsCache[parentId] {
					futureObject = f
				} else {
					var urlComponents = URLComponents(url: URL(string: "files/" + parentId, relativeTo: driveApiBaseURL)!, resolvingAgainstBaseURL: true)!
					urlComponents.queryItems = [URLQueryItem(name: "fields", value: "id,name,parents,ownedByMe")]
					
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .customISO8601
					decoder.keyDecodingStrategy = .useDefaultKeys
					let op = rateLimitGoogleDriveAPIOperation(AuthenticatedJSONOperation<GoogleDriveDoc>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder, retryInfoRecoveryHandler: retryRecoveryHandler(_:sourceError:completionHandler:)))
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
			status[userAndDest.user].nFilesProcessed += 1
			status[userAndDest.user].nBytesProcessed += doc.size.flatMap{ Int($0) } ?? 0
		}
		baseOperationEnded()
	}
	
	private func failDownload(error: Error) {
		_ = try? logFile.logCSVLine([doc.id, "download_error", error.legibleLocalizedDescription])
		status.syncQueue.sync{ status[userAndDest.user].nFailures += 1 }
		result = .failure(error)
		baseOperationEnded()
	}
	
}


/* ****************************************** */

private class RateLimiterOperation : RetryingOperation {
	
	struct Limit {
		
		enum TimeLimit {
			
			case duration(TimeInterval)
			case resetAtDateComponents(DateComponents, calendar: Calendar)
			
		}
		
		var maxCount: Int
		var time: TimeLimit
		
	}
	
	let rateLimitId: String
	let limits: [Limit]
	
	init(id: String, limits l: [Limit]) {
		rateLimitId = id
		limits = l
	}
	
	override func startBaseOperation(isRetry: Bool) {
		/* Try and acquire the lock */
		let timeToWait: TimeInterval? = RateLimiterOperation.countsQueue.sync{
			let timesToWait = limits.compactMap{ limit -> TimeInterval? in
				let previousResetDateO: Date?
				switch limit.time {
				case .duration(let i):                                         previousResetDateO = Date() - i
				case .resetAtDateComponents(let dateComponents, let calendar): previousResetDateO = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .backward)
				}
				
				guard let previousResetDate = previousResetDateO else {return nil}
				
				let nHits: Int
				let counts = RateLimiterOperation.counts[rateLimitId, default: []]
				/* TODO: Optimize this search (reverse search). Currently, the more
				 *       dates are registered, the longer the search! */
				let dateAndOffset = counts.enumerated().first{ $0.element >= previousResetDate } /* The last date that was rate-limited */
				if let dateAndOffset = dateAndOffset {
					nHits = counts.count - dateAndOffset.offset
				} else {
					/* If no dates are after the reset date, that means none of the
					 * registered dates are in the rate-limit period.*/
					nHits = 0
				}
				
				guard nHits >= limit.maxCount else {return nil}
				
				let nextResetDate: Date?
				switch limit.time {
				case .duration(let i):                                                   nextResetDate = (dateAndOffset?.element ?? counts.last).flatMap{ $0 + i }
				case .resetAtDateComponents(let dateComponents, calendar: let calendar): nextResetDate = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward)
				}
				return nextResetDate?.timeIntervalSinceNow
			}
			
			if let t = timesToWait.max() {
				if t >= 0 {return t}
			}
			/* If we don’t wait, we register the call in the counts variable. */
			RateLimiterOperation.counts[rateLimitId, default: []].append(Date())
			return nil
		}
		
		if let t = timeToWait {baseOperationEnded(needsRetryIn: t)}
		else                  {baseOperationEnded()}
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	private static let countsQueue = DispatchQueue(label: "com.happn.officectl.ratelimiter_counts_queue")
	private static var counts = [String: [Date]]()
	
}


/* ****************************************** */

private class LogFile {
	
	convenience init(url: URL, csvHeader cells: [String]) throws {
		try self.init(url: url, header: Data((cells.map{ $0.csvCellValueWithSeparator(csvSep) }.joined(separator: csvSep) + "\n").utf8))
	}
	
	init(url: URL, header: Data? = nil) throws {
		let folder = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
		
		let fileExists = FileManager.default.fileExists(atPath: url.path)
		/* Not sure the explicit file creation this is needed… */
		guard fileExists || FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create log file"])
		}
		
		guard let s = OutputStream(url: url, append: true) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create log file"])
		}
		s.open()
		
		stream = s
		
		if !fileExists, let header = header {
			try logData(header)
		}
	}
	
	deinit {
		stream.close()
	}
	
	func logCSVLine(_ cells: [String]) throws {
		try logLine(cells.map{ $0.csvCellValueWithSeparator(csvSep) }.joined(separator: csvSep))
	}
	
	func logLine(_ line: String) throws {
		try logData(Data((line + "\n").utf8))
	}
	
	func logData(_ data: Data) throws {
		try syncQueue.sync{
			try data.withUnsafeBytes{ bytes in
				let n = bytes.count
				guard stream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: n) == n else {
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to write to log file"])
				}
			}
		}
	}
	
	private let syncQueue = DispatchQueue(label: "com.happn.officectl.logfilewritequeue")
	private let stream: OutputStream
	
}


/* ****************************************** */

private class DownloadDrivesStatus : ActivityIndicatorType {
	
	struct DownloadDriveStatus {
		
		var foundAllFiles: Bool
		var nFilesToProcess: Int
		var nBytesToProcess: Int
		
		var nFilesIgnored: Int /* Files that are not taking any quota in the drive. */
		var nBytesIgnored: Int /* Files that are not taking any quota in the drive. */
		
		var nFilesProcessed: Int
		var nBytesProcessed: Int
		
		var nFailures: Int /* Should always lower than or equal to the number of files processed. */
		
	}
	
	var loadingBarWidth: Int = 27
	
	let syncQueue = DispatchQueue(label: "com.happn.officectl.downloaddrivestatusactivitysync")
	
	func initStatuses(users: [GoogleUser]) {
		syncQueue.sync{
			var res = [GoogleUser: DownloadDriveStatus](minimumCapacity: users.count)
			for u in users {
				res[u] = DownloadDriveStatus(foundAllFiles: false, nFilesToProcess: 0, nBytesToProcess: 0, nFilesIgnored: 0, nBytesIgnored: 0, nFilesProcessed: 0, nBytesProcessed: 0, nFailures: 0)
			}
			statuses = res
		}
	}
	
	/** - Important: Call the subscript on syncQueue, or you might get races. */
	subscript(_ user: GoogleUser) -> DownloadDriveStatus {
		get {
			statuses?[user] ?? DownloadDriveStatus(foundAllFiles: false, nFilesToProcess: 0, nBytesToProcess: 0, nFilesIgnored: 0, nBytesIgnored: 0, nFilesProcessed: 0, nBytesProcessed: 0, nFailures: 0)
		}
		set {
			if statuses == nil {statuses = [GoogleUser: DownloadDriveStatus]()}
			statuses![user] = newValue
		}
	}
	
	/* Note: This method is highly unoptimized. Let’s not care, at least for now. */
	func outputActivityIndicator(to console: Console, state: ActivityIndicatorState) {
		let safeStatuses = syncQueue.sync{ statuses }
		
		guard let statuses = safeStatuses else {
			console.info("Loading Users to Backup…")
			return
		}
		
		console.info("Drive Download Statuses by Users:")
		
		/* Note: We do not check the console size before doing the printing. If
		 *       there is a very long username (or a very small console), the
		 *       output will probably be weird… */
		
		let maxAccountWidth = self.maxAccountWidth ?? statuses.keys.map{ $0.primaryEmail.stringValue.count }.max() ?? 0
		
		var maxFoundFilesWidth = 0
		var maxTreatedFilesWidth = 0
		var maxIgnoredFilesWidth = 0
		var maxFailuresWidth = 0
		var maxFoundBytesWidth = 0
		var maxTreatedBytesWidth = 0
		var maxIgnoredBytesWidth = 0
		for s in statuses.values {
			maxFoundFilesWidth   = max(maxFoundFilesWidth,   numberWidth(s.nFilesToProcess) + (s.foundAllFiles ? 0 : 1))
			maxTreatedFilesWidth = max(maxTreatedFilesWidth, numberWidth(s.nFilesProcessed))
			maxIgnoredFilesWidth = max(maxIgnoredFilesWidth, numberWidth(s.nFilesIgnored))
			maxFailuresWidth     = max(maxFailuresWidth,     numberWidth(s.nFailures))
			maxFoundBytesWidth   = max(maxFoundBytesWidth,   bytesToHumanReadableString(s.nBytesToProcess).count + (s.foundAllFiles ? 0 : 1))
			maxTreatedBytesWidth = max(maxTreatedBytesWidth, bytesToHumanReadableString(s.nBytesProcessed).count)
			maxIgnoredBytesWidth = max(maxIgnoredBytesWidth, bytesToHumanReadableString(s.nBytesIgnored).count)
		}
		
		for user in statuses.keys.sorted(by: { $0.primaryEmail.stringValue < $1.primaryEmail.stringValue }) {
			let status = statuses[user]!
			
			var line = [ConsoleTextFragment]()
			let useremail = user.primaryEmail.stringValue
			
			line.append(ConsoleTextFragment(string: "   - ", style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxAccountWidth - useremail.count) + useremail, style: .info))
			line.append(ConsoleTextFragment(string: " [", style: .plain))
			if status.foundAllFiles {
				/* Progress bar w/ actual progress shown. */
				let progressOK = status.nFilesToProcess == 0 ? 1.0 : Float(status.nFilesProcessed) / Float(status.nFilesToProcess)
				let progressError = status.nFilesToProcess == 0 ? 0.0 : Float(status.nFailures) / Float(status.nFilesToProcess)
				let leftOK = min(Int((Float(loadingBarWidth) * progressOK).rounded()), loadingBarWidth)
				let leftError = min(Int((Float(loadingBarWidth) * progressError).rounded()), loadingBarWidth)
				let left = min(leftOK + leftError, loadingBarWidth)
				line.append(ConsoleTextFragment(string: String(repeating: "=", count: leftOK),                 style: .plain))
				line.append(ConsoleTextFragment(string: String(repeating: "=", count: leftError),              style: .error))
				line.append(ConsoleTextFragment(string: String(repeating: " ", count: loadingBarWidth - left), style: .plain))
			} else {
				/* Indeterminate progress bar as we don’t know the progress. */
				let bulletPosition: Int
				switch state {
				case .active(tick: let t):
					let period = loadingBarWidth - 1
					let offset  = Int(t % UInt(period))
					let reverse = Int(t % UInt(period*2)) >= period
					bulletPosition = !reverse ? offset : loadingBarWidth - offset - 1
					
				default:
					bulletPosition = 0
				}
				line.append(ConsoleTextFragment(string: String(repeating: " ", count: bulletPosition), style: .plain))
				line.append(ConsoleTextFragment(string: "•", style: .plain))
				line.append(ConsoleTextFragment(string: String(repeating: " ", count: loadingBarWidth - bulletPosition - 1), style: .plain))
			}
			/* Showing the number of downloaded files */
			line.append(ConsoleTextFragment(string: "] Downloaded ", style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxTreatedFilesWidth - numberWidth(status.nFilesProcessed)), style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFilesProcessed), style: .plain))
			line.append(ConsoleTextFragment(string: "/", style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFilesToProcess), style: status.foundAllFiles ? .success : .info))
			if !status.foundAllFiles {
				line.append(ConsoleTextFragment(string: "+", style: .info))
			}
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxFoundFilesWidth - (numberWidth(status.nFilesToProcess) + (status.foundAllFiles ? 0 : 1))), style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxIgnoredFilesWidth - numberWidth(status.nFilesIgnored)), style: .plain))
			line.append(ConsoleTextFragment(string: " (", style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFilesIgnored) + " ignored", style: .warning))
			line.append(ConsoleTextFragment(string: "), ", style: .plain))
			/* Showing the number of downloaded bytes */
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxTreatedBytesWidth - bytesToHumanReadableString(status.nBytesProcessed).count), style: .plain))
			line.append(ConsoleTextFragment(string: bytesToHumanReadableString(status.nBytesProcessed), style: .plain))
			line.append(ConsoleTextFragment(string: "/", style: .plain))
			line.append(ConsoleTextFragment(string: bytesToHumanReadableString(status.nBytesToProcess), style: status.foundAllFiles ? .success : .info))
			if !status.foundAllFiles {
				line.append(ConsoleTextFragment(string: "+", style: .info))
			}
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxFoundBytesWidth - (bytesToHumanReadableString(status.nBytesToProcess).count + (status.foundAllFiles ? 0 : 1))), style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxIgnoredBytesWidth - bytesToHumanReadableString(status.nBytesIgnored).count), style: .plain))
			line.append(ConsoleTextFragment(string: " (", style: .plain))
			line.append(ConsoleTextFragment(string: bytesToHumanReadableString(status.nBytesIgnored) + " ignored", style: .warning))
			line.append(ConsoleTextFragment(string: "); failed ", style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxFailuresWidth - numberWidth(status.nFailures)), style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFailures), style: status.nFailures == 0 ? .success : .error))
			
			console.output(ConsoleText(fragments: line))
		}
	}
	
	private var maxAccountWidth: Int?
	private var statuses: [GoogleUser: DownloadDriveStatus]?
	
	private func bytesToHumanReadableString(_ bytes: Int) -> String {
		func nextStep(_ currentValue: Double, currentSuffixes: [String]) -> String {
			let r = Int(currentValue.rounded())
			if r < 1024 || currentSuffixes.count == 1 {
				return String(r) + currentSuffixes.first!
			}
			return nextStep(currentValue/1024, currentSuffixes: Array(currentSuffixes.dropFirst()))
		}
		return nextStep(Double(bytes), currentSuffixes: ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"])
	}
	
	private func numberWidth(_ n: Int) -> Int {
		switch n {
		case 0: return 1
		case ...(-1): return numberWidth(n) + 1
		case 1...:    return Int(log10(Float(n))) + 1
		default: return 1 /* I don’t know… */
		}
	}
	
}


/* ****************************************** */

private struct GoogleDriveFilesList : Codable {
	
	var files: [GoogleDriveDoc]?
	
	var kind: String
	var incompleteSearch: Bool
	
	var nextPageToken: String?
	
}

private struct GoogleDriveDoc : Codable {
	
	struct GoogleDriveDocUser : Codable {
		
		var emailAddress: Email?
		var me: Bool?
		var kind: String?
		var displayName: String?
		var photoLink: URL?
		var permissionId: String?
		
	}
	
	var id: String
	var name: String?
	var mimeType: String?
	var originalFilename: String?
	
	var kind: String?
	
	var md5Checksum: String?
	var headRevisionId: String?
	
	var createdTime: Date?
	var modifiedTime: Date?
	
	var isAppAuthorized: Bool?
	
	var ownedByMe: Bool
	var owners: [GoogleDriveDocUser]?
	
	var modifiedByMe: Bool?
	var lastModifyingUser: GoogleDriveDocUser?
	
	var size: String?
	var quotaBytesUsed: String?
	
	var shared: Bool?
	var starred: Bool?
	var viewedByMe: Bool?
	var trashed: Bool?
	var explicitlyTrashed: Bool?
	
	var hasThumbnail: Bool?
	var fileExtension: String?
	var fullFileExtension: String?
	
	var capabilities: [String: Bool]? /* Too lazy to create the Capabilities object… */
	var copyRequiresWriterPermission: Bool?
	var viewersCanCopyContent: Bool?
	var writersCanShare: Bool?
	var permissionIds: [String]?
	
	var iconLink: URL?
	var webViewLink: URL?
	var webContentLink: URL?
	var thumbnailVersion: String?
	var thumbnailLink: URL?
	
	var parents: [String]? /* These are actually parent ids! */
	var spaces: [String]?
	
	var version: String?
	
}


/* ****************************************** */

private extension String {
	
	func csvCellValueWithSeparator(_ sep: String) -> String {
		guard sep.utf16.count == 1, sep != "\"", sep != "\n", sep != "\r" else {fatalError("Cannot use \"\(sep)\" as a CSV separator")}
		/* We use the large “newlines” character set instead of simply \n and \r
		 * to solve some problems when solving merge conflicts with FileMerge.
		 * (FileMerge sees a weird UTF-8 newline and proposes to solve the problem
		 * by converting the newlines in the file to CR, LF or CRLF. When it does
		 * that, a field containing such a character becomes incomplete and the
		 * line stops there.) */
		if rangeOfCharacter(from: CharacterSet(charactersIn: "\(sep)\"").union(.newlines)) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = replacingOccurrences(of: "\"", with: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return self
		}
	}
	
}
