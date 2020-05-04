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
	let app = context.application
	let officeKitConfig = app.officeKitConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	let serviceId = f.getString(name: "service-id")
	let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
	
	let downloadsDestinationFolder = URL(fileURLWithPath: f.getString(name: "downloads-destination-folder")!, isDirectory: true)
	
	let disabledUserSuffix = f.getString(name: "disabled-email-suffix")
	let usersFilter = (args.isEmpty ? nil : args)?.map{ EmailSrcAndDst(emailStr: $0, disabledUserSuffix: disabledUserSuffix, logger: app.logger) }
	
	let linkify = !f.getBool(name: "nolinkify")!
	let skipIfArchiveFound = !f.getBool(name: "no-skip-if-archive-exists")!
	let archiveDestinationFolderStr = (f.getBool(name: "archive")! ? try nil2throw(f.getString(name: "archives-destination-folder")) : nil)
	let archiveDestinationFolder = archiveDestinationFolderStr.flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
	
	try app.auditLogger.log(action: "Backing up mails w/ service \(serviceId ?? "<inferred service>"), users filter \(usersFilter?.map{ $0.debugDescription }.joined(separator: ",") ?? "<no filter>"), \(linkify ? "w/": "w/o") linkification, \(archiveDestinationFolder != nil ? "w/": "w/o") archiving.", source: .cli)
	
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
	.flatMap{ filteredUsers -> EventLoopFuture<[GoogleUserAndDest]> in /* Backup given mails */
		let options = BackupMailOptions(flags: f, console: context.console, mainConnector: googleConnector, users: filteredUsers)
		
		return EventLoopFuture<[URL]>.future(from: FetchAllMailsOperation(options: options), on: eventLoop, resultRetriever: {
			try throwIfError($0.fetchError)
			return $0.options.users
		})
	}
	.flatMap{ usersAndDests -> EventLoopFuture<[GoogleUserAndDest]> in /* Linkify the backed-up emails */
		guard linkify && usersAndDests.count > 0 else {return eventLoop.future(usersAndDests)}
		
		context.console.info("Optimizing backups size")
		let q = OperationQueue()
		q.maxConcurrentOperationCount = 2 /* No need to spam the hard-drive… */
		let operations = usersAndDests.filter{ linkify && $0.archiveDestination != nil }.map{ $0.downloadDestination }.compactMap{ url -> LinkifyOperation? in
			do    {return try LinkifyOperation(folderURL: url, stopOnErrors: false)}
			catch {context.console.warning("cannot linkify backup at URL \(url.absoluteString)"); return nil}
		}
		let futureFromOperations = EventLoopFuture<[Result<Void, Error>]>.executeAll(operations, on: eventLoop, resultRetriever: { op -> Void in
			if op.errors.count > 0 {
				context.console.warning("got errors when linkifying backup at URL \(op.folderURL.absoluteString):")
				for (url, error) in op.errors {
					context.console.warning("   \(url.absoluteString): \(error)")
				}
			}
			return ()
		})
		return futureFromOperations.transform(to: usersAndDests)
	}
	.flatMap{ usersAndDests -> EventLoopFuture<Void> in /* Compressing the backed-up emails */
		guard archiveDestinationFolder != nil && usersAndDests.count > 0 else {return eventLoop.future()}
		
		context.console.info("Compressing backups")
		let q = OperationQueue()
		q.maxConcurrentOperationCount = 4 /* Seems fair on today’s hardware… */
		let operations = usersAndDests.compactMap{ userAndDest -> TarOperation? in
			return userAndDest.archiveDestination.flatMap{ archiveDestination in
				/* Will create the enclosing folder if not already there (a bit of
				 * trivia: the the call don’t fail if the directory already exist). */
				_ = try? FileManager.default.createDirectory(at: archiveDestination.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
				return TarOperation(
					sources: [userAndDest.downloadDestination.lastPathComponent],
					relativeTo: userAndDest.downloadDestination.deletingLastPathComponent(),
					destination: archiveDestination,
					compress: true,
					deleteSourcesOnSuccess: true
				)
			}
		}
		let futureFromOperations = EventLoopFuture<[Result<Void, Error>]>.executeAll(operations, on: eventLoop, resultRetriever: { op -> Void in
			if let tarError = op.tarError {
				context.console.warning("could not compress \(op.sources.first!): \(tarError)")
			}
			/* We have at most one deletion error because there is only one source.*/
			if let deletionError = op.sourceDeletionErrors.randomElement() {
				context.console.warning("could not delete \(deletionError.key): \(deletionError.value)")
			}
			return ()
		})
		return futureFromOperations.transform(to: ())
	}
	return f
}


/* ****************************************** */

struct BackupMailOptions {
	
	let offlineimapConfigFileURL: URL
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
	
	let console: Console
	
	let mainConnector: GoogleJWTConnector
	let users: [GoogleUserAndDest]
	
	init(flags f: Flags, console csl: Console, mainConnector c: GoogleJWTConnector, users u: [GoogleUserAndDest]) {
		offlineimapConfigFileURL = URL(fileURLWithPath: f.getString(name: "offlineimap-config-file")!, isDirectory: false)
		maxConcurrentSync = f.getInt(name: "max-concurrent-account-sync")
		offlineimapOutputFileURL = f.getString(name: "offlineimap-output").map{ URL(fileURLWithPath: $0, isDirectory: false) }
		
		console = csl
		
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
			let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
			
			let futureAccessTokens = options.users.map{ futureAccessToken(for: $0, eventLoop: eventLoop) }
			let f = EventLoopFuture.reduce(into: (tokens: [GoogleUser: (token: String, destination: URL)](), minExpirationDate: Date.distantFuture), futureAccessTokens, on: eventLoop, { (currentResult, newResult) in
				currentResult.minExpirationDate = min(currentResult.minExpirationDate, newResult.2)
				currentResult.tokens[newResult.0.user] = (newResult.1, newResult.0.downloadDestination)
			})
			.flatMap{ (info: (tokens: [GoogleUser : (token: String, destination: URL)], minExpirationDate: Date)) -> EventLoopFuture<Void> in
				let operation = OfflineimapRunOperation(userInfos: info.tokens, tokensMinExpirationDate: info.minExpirationDate, options: self.options)
				return EventLoopFuture<Void>.future(from: operation, on: eventLoop, resultRetriever: { if let e = $0.runError {throw e} })
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
	
	private func futureAccessToken(for userAndDest: GoogleUserAndDest, eventLoop: EventLoop) -> EventLoopFuture<(GoogleUserAndDest, String, Date)> {
		let scope = Set(arrayLiteral: "https://mail.google.com/")
		let connector = GoogleJWTConnector(from: options.mainConnector, userBehalf: userAndDest.user.primaryEmail.stringValue)
		return connector.connect(scope: scope, eventLoop: eventLoop)
		.flatMap{
			let promise: EventLoopPromise<(GoogleUserAndDest, String, Date)> = eventLoop.makePromise()
			
			if let token = connector.token, let expirationDate = connector.expirationDate {promise.succeed((userAndDest, token, expirationDate))}
			else                                                                          {promise.fail(NSError(domain: "com.happn.officectl", code: 42, userInfo: [NSLocalizedDescriptionKey: "Internal error"]))}
			
			return promise.futureResult
		}
	}
	
}

class OfflineimapRunOperation : RetryingOperation {
	
	struct ConfigExpiredError : Error {}
	
	let console: Console
	
	let tokensMinExpirationDate: Date
	let userInfos: [GoogleUser: (token: String, destination: URL)]
	
	let configurationFileURL: URL
	let offlineimapOutputFileURL: URL?
	let maxConcurrentOfflineimapSyncTasks: Int?
	
	var offlineimapProcess: Process?
	
	var runError: Error?
	
	init(userInfos i: [GoogleUser: (token: String, destination: URL)], tokensMinExpirationDate date: Date, options: BackupMailOptions) {
		userInfos = i
		console = options.console
		configurationFileURL = options.offlineimapConfigFileURL
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
			
			/* Launching offlineimap */
			do    {try process.run()}
			catch {offlineimapProcess = nil; throw error}
			
			console.info("Waiting on offlineimap…")
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
		
		console.info("Removing offlineimap config file")
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
		process.executableURL = URL(fileURLWithPath: "/usr/local/bin/offlineimap")
		process.arguments = ["-c", configurationFileURL.path]
		#if !os(Linux)
			process.standardInput = FileHandle.nullDevice /* Forces failure of getting user pass from input when auth token expires. */
			process.standardOutput = processOutput
		#endif
		
		return process
	}
	
	private func offlineimapConfigExpired() {
		console.info("offlineimap config expired! Stopping offlineimap...")
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
		signal(SIGINT,  { _ in OfficeKitConfig.logger?.info("Received SIGINT");  NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SigInt"),  object: nil) })
		signal(SIGTERM, { _ in OfficeKitConfig.logger?.info("Received SIGTERM"); NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SigTerm"), object: nil) })
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
		console.info("Generating config for offlineimap")
		
		guard userInfos.count > 0 else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "No access tokens…"])
		}
		
		guard userInfos.keys.first(where: { $0.id.value == nil }) == nil else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got a user with no id fetched!"])
		}
		
		/* About maxsyncaccounts:
		 *    We default arbitrarily to 4 (ncores/2 would probably be better).
		 *    Even on an 8-core machine, offlineimap seems greedy, and I got a
		 *    "pthread_cond_wait: Resource busy" error with maxsyncaccounts = 8.
		 * About the forced unwrapped below, we know the id is fetched on all the
		 * users (checked above). */
		let config = """
		[general]
		ui = MachineUI
		maxsyncaccounts = \(maxConcurrentOfflineimapSyncTasks ?? 4)
		accounts = \(userInfos.keys.map{ "AccountUserID_" + $0.id.value! }.joined(separator: ","))
		
		
		
		""" + userInfos.map{ userInfo -> String in
			let (user, (token, destinationURL)) = userInfo
			/* About the sslcacertfile:
			 *    - When using the system (macOS) Python, we must use the dummycert trick (sslcacertfile = ~/.dummycert_for_python.pem);
			 *    - When using homebrew’s Python2 (offlineimap uses Python2…), we must specify the cacert file. We use the one from openssl. */
			/* About the ssl_version:
			 *    - When using Python2 w/ OpenSSL 1.1.1, offlineimap cannot validate Gogle’s certificate. We can fix that by forcing using the TLS 1.2 protocol. (youhou) */
			return """
			[Account AccountUserID_\(user.id.value!)]
			localrepository = LocalRepoID_\(user.id.value!)
			remoterepository = RemoteRepoID_\(user.id.value!)
			
			[Repository LocalRepoID_\(user.id.value!)]
			type = Maildir
			localfolders = \(destinationURL.path)
			
			[Repository RemoteRepoID_\(user.id.value!)]
			type = Gmail
			readonly = True
			remoteuser = \(user.primaryEmail.stringValue)
			oauth2_access_token = \(token)
			sslcacertfile = /usr/local/etc/openssl/cert.pem
			ssl_version = tls1_2
			
			"""
		}.joined(separator: "\n")
		
		try Data(config.utf8).write(to: configurationFileURL)
	}
	
}
