/*
 * mails.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import RetryingOperation
import Vapor

import OfficeKit



func backupMails(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	
	let userBehalf = f.getString(name: "google-admin-email")!
	let usersFilter = (f.getString(name: "emails-to-backup")?.components(separatedBy: ",")).flatMap{ Set($0) }
	
	let googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
	let f = googleConnector.connect(scope: GoogleUserSearchOperation.searchScopes, asyncConfig: asyncConfig)
	.then{ _ -> EventLoopFuture<[GoogleUser]> in
		let searchOp = GoogleUserSearchOperation(searchedDomain: "happn.fr", googleConnector: googleConnector)
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: { try $0.result.successValueOrThrow() })
	}
	.then{ happnFrUsers -> EventLoopFuture<[GoogleUser]> in
		let searchOp = GoogleUserSearchOperation(searchedDomain: "happnambassadeur.com", googleConnector: googleConnector)
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: { try happnFrUsers + $0.result.successValueOrThrow() })
	}
	.then{ allUsers -> EventLoopFuture<Void> in
		let filteredUsers = allUsers.filter{ usersFilter?.contains($0.primaryEmail.stringValue) ?? true }
		let options = BackupMailOptions(flags: f, asyncConfig: asyncConfig, mainConnector: googleConnector, users: filteredUsers)
		
		return asyncConfig.eventLoop.future(from: FetchAllMailsOperation(options: options), queue: asyncConfig.operationQueue, resultRetriever: { if let e = $0.fetchError {throw e} })
	}
	/*.then Linkify the backups? */
	return f
}


/* ****************************************** */

struct BackupMailOptions {
	
	let offlineimapConfigFileURL: URL
	let backupDestinationFolder: URL
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
	
	let asyncConfig: AsyncConfig
	
	let mainConnector: GoogleJWTConnector
	let users: [GoogleUser]
	
	init(flags f: Flags, asyncConfig conf: AsyncConfig, mainConnector c: GoogleJWTConnector, users u: [GoogleUser]) {
		offlineimapConfigFileURL = URL(fileURLWithPath: f.getString(name: "offlineimap-config-file")!, isDirectory: false)
		backupDestinationFolder = URL(fileURLWithPath: f.getString(name: "destination")!, isDirectory: true)
		maxConcurrentSync = f.getInt(name: "max-concurrent-account-sync")
		offlineimapOutputFileURL = f.getString(name: "offlineimap-output").map{ URL(fileURLWithPath: $0, isDirectory: false) }
		
		asyncConfig = conf
		
		mainConnector = c
		users = u
	}
	
}

class FetchAllMailsOperation : RetryingOperation {
	
	let options: BackupMailOptions
	
	var fetchError: Error?
	
	init(options o: BackupMailOptions) {
		options = o
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	override func startBaseOperation(isRetry: Bool) {
		do {
			/* Will create the folder if not already there, does not error out if
			 * already there. */
			try FileManager.default.createDirectory(at: options.backupDestinationFolder, withIntermediateDirectories: true, attributes: nil)
			
			let futureAccessTokens = options.users.map{ futureAccessToken(for: $0) }
			let f = EventLoopFuture.reduce(into: (tokens: [GoogleUser: String](), minExpirationDate: Date.distantFuture), futureAccessTokens, eventLoop: options.asyncConfig.eventLoop, { (currentResult, newResult) in
				currentResult.minExpirationDate = min(currentResult.minExpirationDate, newResult.2)
				currentResult.tokens[newResult.0] = newResult.1
			})
			.then { (info: (tokens: [GoogleUser : String], minExpirationDate: Date)) -> EventLoopFuture<Void> in
				let operation = OfflineimapRunOperation(userTokens: info.tokens, tokensMinExpirationDate: info.minExpirationDate, options: self.options)
				return self.options.asyncConfig.eventLoop.future(from: operation, queue: self.options.asyncConfig.operationQueue, resultRetriever: { if let e = $0.runError {throw e} })
			}
			try f.wait()
			baseOperationEnded()
		} catch _ as OfflineimapRunOperation.ConfigExpiredError {
			baseOperationEnded(needsRetryIn: 0)
		} catch {
			fetchError = error
			baseOperationEnded()
		}
	}
	
	private func futureAccessToken(for user: GoogleUser) -> EventLoopFuture<(GoogleUser, String, Date)> {
		let scope = Set(arrayLiteral: "https://mail.google.com/")
		let connector = GoogleJWTConnector(from: options.mainConnector, userBehalf: user.primaryEmail.stringValue)
		return connector.connect(scope: scope, asyncConfig: options.asyncConfig)
		.then{
			let promise: EventLoopPromise<(GoogleUser, String, Date)> = self.options.asyncConfig.eventLoop.newPromise()
			
			if let token = connector.token, let expirationDate = connector.expirationDate {promise.succeed(result: (user, token, expirationDate))}
			else                                                                          {promise.fail(error: NSError(domain: "com.happn.officectl", code: 42, userInfo: [NSLocalizedDescriptionKey: "Internal error"]))}
			
			return promise.futureResult
		}
	}
	
}

class OfflineimapRunOperation : RetryingOperation {
	
	struct ConfigExpiredError : Error {}
	
	let tokensMinExpirationDate: Date
	let userTokens: [GoogleUser: String]
	
	let configurationFileURL: URL
	let destinationFolderURL: URL
	let offlineimapOutputFileURL: URL?
	let maxConcurrentOfflineimapSyncTasks: Int?
	
	var offlineimapProcess: Process?
	
	var runError: Error?
	
	init(userTokens t: [GoogleUser: String], tokensMinExpirationDate date: Date, options: BackupMailOptions) {
		userTokens = t
		configurationFileURL = options.offlineimapConfigFileURL
		destinationFolderURL = options.backupDestinationFolder
		offlineimapOutputFileURL = options.offlineimapOutputFileURL
		maxConcurrentOfflineimapSyncTasks = options.maxConcurrentSync
		
		tokensMinExpirationDate = date
		timer = DispatchSource.makeTimerSource(flags: [], queue: timerQueue)
	}
	
	deinit {
		assert(offlineimapProcess == nil)
		cancelKillTimer()
		releaseSignalHandlers()
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		do {
			try updateOfflineimapConfig()
			
			setupKillTimer()
			setupSignalHandlers()
			
			/* *** Creating and launching the offlineimap process. *** */
			
			let process = try createOfflineimapProcess()
			offlineimapProcess = process
			
			print("Waiting on offlineimap…")
			process.launch()
			process.waitUntilExit()
			offlineimapProcess = nil
			
			/* *** offlineimap has now finished running. Let's end the operation. *** */
			
			releaseSignalHandlers()
			cancelKillTimer()
			
			if process.terminationStatus != 0 {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "offlineimap exited with status \(process.terminationStatus)"])
			}
		} catch {
			if runError == nil {runError = error}
		}
		
		print("Removing offlineimap config file")
		_ = try? FileManager.default.removeItem(at: configurationFileURL)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var timer: DispatchSourceTimer
	private let timerQueue = DispatchQueue(label: "OfflineimapRun Timer Queue")
	
	private let signalQueue = OperationQueue()
	private var signalNotifObservers = [NSObjectProtocol]()
	
	private func createOfflineimapProcess() throws -> Process {
		if let offlineimapOutputFileURL = offlineimapOutputFileURL {
			guard FileManager.default.createFile(atPath: offlineimapOutputFileURL.path, contents: nil, attributes: nil) else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create offlineimap output file"])
			}
		}
		
		/* About processOutput, an interesting thing to do would be to set it to a
		 * a Pipe() so we can parse the output in real-time and process it! */
		let processOutput = try offlineimapOutputFileURL.map{ try FileHandle(forWritingTo: $0) } ?? FileHandle.nullDevice
		processOutput.seekToEndOfFile(); processOutput.write(Data("***** \(Date()): NEW OFFLINEIMAP RUN!\n".utf8))
		
		let process = Process()
		process.launchPath = "/usr/local/bin/offlineimap"
		process.arguments = ["-c", configurationFileURL.path]
		process.standardInput = FileHandle.nullDevice /* Forces failure of getting user pass from input when auth token expires. */
		process.standardOutput = processOutput
		
		return process
	}
	
	private func offlineimapConfigExpired() {
		print("offlineimap config expired! Stopping offlineimap...")
		if runError == nil {runError = ConfigExpiredError()}
		killOfflineimap(terminate: false)
	}
	
	/** If terminate is false, sends an interrupt signal. */
	private func killOfflineimap(terminate: Bool) {
		guard let p = offlineimapProcess, p.isRunning else {return}
		if terminate {p.terminate()}
		else         {p.interrupt()}
	}
	
	private func setupKillTimer() {
		/* We guess in 5 minutes offlineimap will have time to close. If not, it's
		 * no big deal anyway, it will simply not be able to finish whatever it
		 * was doing remote side before closing, but we'll still relaunch it when
		 * it finishes. */
		let killTime = max(
			DispatchTime.now() + .milliseconds(Int(tokensMinExpirationDate.timeIntervalSinceNow*1000)) - .seconds(5*60),
			DispatchTime.now() + .seconds(5)
		)
		timer.setEventHandler{ [weak self] in self?.offlineimapConfigExpired() }
		timer.schedule(deadline: killTime, leeway: .milliseconds(250))
		timer.resume()
	}
	
	private func cancelKillTimer() {
		timer.cancel()
	}
	
	private func interruptReceived() {
		runError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "SIGINT received"])
		killOfflineimap(terminate: false)
	}
	
	private func terminateReceived() {
		runError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "SIGTERM received"])
		killOfflineimap(terminate: true)
	}
	
	private func setupSignalHandlers() {
		let nc = NotificationCenter.default
		signalNotifObservers.append(nc.addObserver(forName: NSNotification.Name(rawValue: "SigInt"),  object: nil, queue: signalQueue) { [weak self] _ in self?.interruptReceived() })
		signalNotifObservers.append(nc.addObserver(forName: NSNotification.Name(rawValue: "SigTerm"), object: nil, queue: signalQueue) { [weak self] _ in self?.terminateReceived() })
		signal(SIGINT,  { _ in print("Received SIGINT");  NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SigInt"),  object: nil) })
		signal(SIGTERM, { _ in print("Received SIGTERM"); NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SigTerm"), object: nil) })
	}
	
	private func releaseSignalHandlers() {
		signal(SIGTERM, nil)
		signal(SIGINT,  nil)
		signalNotifObservers.forEach{ NotificationCenter.default.removeObserver($0) }
		signalNotifObservers.removeAll()
	}
	
	/** Writes the offlineimap config file in configFileURL and returns the
	expiration date of the config.
	
	- returns: The date after which the configuration file will not be valid
	anymore (access tokens expired). */
	private func updateOfflineimapConfig() throws {
		print("Generating config for offlineimap")
		
		guard userTokens.count > 0 else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "No access tokens…"])
		}
		
		/* About maxsyncaccounts:
		 *    We default arbitrarily to 4 (ncores/2 would probably be better).
		 *    Even on an 8-core machine, offlineimap seems greedy, and I got a
		 *    "pthread_cond_wait: Resource busy" error with maxsyncaccounts = 8. */
		let config = """
		[general]
		ui = MachineUI
		maxsyncaccounts = \(maxConcurrentOfflineimapSyncTasks ?? 4)
		accounts = \(userTokens.keys.map{ "AccountUserID_" + $0.id }.joined(separator: ","))
		
		
		
		""" + userTokens.map{ userTokenPair -> String in
			let (user, token) = userTokenPair
			/* About the sslcacertfile:
			 *    - When using the system (macOS) Python, we must use the dummycert trick (sslcacertfile = ~/.dummycert_for_python.pem);
			 *    - When using homebrew’s Python2 (offlineimap uses Python2…), we must specify the cacert file. We use the one from openssl. */
			return """
			[Account AccountUserID_\(user.id)]
			localrepository = LocalRepoID_\(user.id)
			remoterepository = RemoteRepoID_\(user.id)
			
			[Repository LocalRepoID_\(user.id)]
			type = Maildir
			localfolders = \(URL(fileURLWithPath: user.primaryEmail.stringValue, relativeTo: destinationFolderURL).path)
			
			[Repository RemoteRepoID_\(user.id)]
			type = Gmail
			readonly = True
			remoteuser = \(user.primaryEmail.stringValue)
			oauth2_access_token = \(token)
			sslcacertfile = /usr/local/etc/openssl/cert.pem
			
			"""
		}.joined(separator: "\n")
		
		try Data(config.utf8).write(to: configurationFileURL)
	}
	
}
