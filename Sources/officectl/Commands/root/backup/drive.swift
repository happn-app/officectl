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
import Vapor



private let driveApiBaseURL = URL(string: "https://www.googleapis.com/drive/v3/")!

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
				let progress = status.nFilesToProcess == 0 ? 1.0 : Float(status.nFilesProcessed) / Float(status.nFilesToProcess)
				let left = min(Int((Float(loadingBarWidth) * progress).rounded()), loadingBarWidth)
				line.append(ConsoleTextFragment(string: String(repeating: "=", count: left),                   style: .plain))
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

func backupDrive(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let officeKitConfig = app.officeKitConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	let serviceId = f.getString(name: "service-id")
	let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
	
	let downloadsDestinationFolder = URL(fileURLWithPath: f.getString(name: "downloads-destination-folder")!, isDirectory: true)
	
	let disabledUserSuffix = f.getString(name: "disabled-email-suffix")
	let usersFilter = (args.isEmpty ? nil : args)?.map{ EmailSrcAndDst(emailStr: $0, disabledUserSuffix: disabledUserSuffix, logger: app.logger) }
	
	let eraseDownloadedFiles = f.getBool(name: "erase-downloaded-files")
	let skipIfArchiveFound = !f.getBool(name: "no-skip-if-archive-exists")!
	let archiveDestinationFolderStr = (f.getBool(name: "archive")! ? try nil2throw(f.getString(name: "archives-destination-folder")) : nil)
	let archiveDestinationFolder = archiveDestinationFolderStr.flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
	
	try app.auditLogger.log(action: "Backing up mails w/ service \(serviceId ?? "<inferred service>"), users filter \(usersFilter?.map{ $0.debugDescription }.joined(separator: ",") ?? "<no filter>"), \(archiveDestinationFolder != nil ? "w/": "w/o") archiving.", source: .cli)
	
	let downloadDriveStatus = DownloadDrivesStatus()
	let consoleActivity = downloadDriveStatus.newActivity(for: context.console)
	consoleActivity.start()
	
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
				/* TODO: Properly report the error (say this user got an error, not just here are the error!) */
				throw ErrorCollection(errors.map{ $0.1 })
			}
			return filteredUsers
		}
	}
	.flatMap{ $0 }
	.transform(to: ())
	.always{ r in
		switch r {
		case .success: consoleActivity.succeed()
		case .failure: consoleActivity.fail()
		}
	}
	
	return f
}


/* ****************************************** */

private class DownloadDriveOperation : RetryingOperation {
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatus
	let logFile: LogFile
	
	let userAndDest: GoogleUserAndDest
	
	let downloadFilesQueue: OperationQueue
	
	var error: Error? = OperationIsNotFinishedError()
	
	init(googleConnector gc: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatus, userAndDest uad: GoogleUserAndDest, downloadFilesQueue dfq: OperationQueue) throws {
		status = s
		eventLoop = el
		userAndDest = uad
		downloadFilesQueue = dfq
		connector = GoogleJWTConnector(from: gc, userBehalf: userAndDest.user.primaryEmail.stringValue)
		logFile = try LogFile(url: userAndDest.downloadDestination.appendingPathComponent(" logs.txt", isDirectory: false))
	}
	
	override func startBaseOperation(isRetry: Bool) {
		let scope = Set(arrayLiteral: "https://www.googleapis.com/auth/drive.readonly")
		_ = connector.connect(scope: scope, eventLoop: eventLoop)
		.flatMap{ _ in self.fetchAndDownloadDriveDocs(connector: self.connector, currentListOfFiles: [], nextPageToken: nil) }
		.flatMap{ futures in EventLoopFuture.whenAllComplete(futures, on: self.eventLoop) }
		.flatMapThrowing{ res -> Void in
			self.baseOperationEnded()
			return ()
		}
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	private func fetchAndDownloadDriveDocs(connector: GoogleJWTConnector, currentListOfFiles: [EventLoopFuture<GoogleDriveDoc>], nextPageToken: String?) -> EventLoopFuture<[EventLoopFuture<GoogleDriveDoc>]> {
		var urlComponents = URLComponents(url: URL(string: "files?fields=files/*,incompleteSearch,kind,nextPageToken", relativeTo: driveApiBaseURL)!, resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [URLQueryItem(name: "fields", value: "nextPageToken,files/*,kind,incompleteSearch")]
		if let t = nextPageToken {urlComponents.queryItems!.append(URLQueryItem(name: "pageToken", value: t))}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<GoogleDriveFilesList>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		return EventLoopFuture<GoogleDriveFilesList>.future(from: op, on: self.eventLoop)
		.flatMap{ newFilesList in
			var newFullListOfFiles = currentListOfFiles
			if let files = newFilesList.files {
				var nBytesFound = 0
				var nBytesIgnored = 0
				var nFilesIgnored = 0
				for file in files {
					/* We keep the files I own, or whose quota is either invalid
					 * (cannot be converted to an Int) or is > 0 */
					let bytes = file.size.flatMap{ Int($0) } ?? 0
					let quota = file.quotaBytesUsed.flatMap({ Int($0) })
					guard file.ownedByMe || quota == nil || quota! > 0 else {
						nFilesIgnored += 1
						nBytesIgnored += bytes
						continue
					}
					
					nBytesFound += bytes
					
					let op = DownloadFileFromDriveOperation(googleConnector: connector, eventLoop: self.eventLoop, status: self.status, userAndDest: self.userAndDest, doc: file)
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
	
	let userAndDest: GoogleUserAndDest
	let doc: GoogleDriveDoc
	
	var result = Result<GoogleDriveDoc, Error>.failure(OperationIsNotFinishedError())
	
	init(googleConnector gc: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatus, userAndDest uad: GoogleUserAndDest, doc d: GoogleDriveDoc) {
		doc = d
		status = s
		connector = gc
		eventLoop = el
		userAndDest = uad
	}
	
	override func startBaseOperation(isRetry: Bool) {
		self.status.syncQueue.sync{
			status[userAndDest.user].nFailures += 1
		}
		
//		self.status.syncQueue.sync{
//			status[userAndDest.user].nFilesProcessed += 1
//			status[userAndDest.user].nBytesProcessed += doc.size.flatMap{ Int($0) } ?? 0
//		}
		
		baseOperationEnded()
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
}


/* ****************************************** */

private class LogFile {
	
	init(url: URL) throws {
		let folder = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
		
		/* Not sure this is needed… */
		guard FileManager.default.fileExists(atPath: url.path) || FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create log file"])
		}
		
		guard let s = OutputStream(url: url, append: true) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create log file"])
		}
		s.open()
		
		stream = s
	}
	
	deinit {
		stream.close()
	}
	
	func writeData(_ data: Data) throws {
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
	
	var iconLink: URL?
	var webViewLink: URL?
	var webContentLink: URL?
	var thumbnailVersion: String?
	var thumbnailLink: URL?
	
	var parents: [String]? /* These are actually parent ids! */
	var spaces: [String]?
	
	var version: String?
	
}
