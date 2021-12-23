/*
 * mails.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser
import Email
import RetryingOperation
import Vapor

import OfficeKit



struct BackupMailsCommand : ParsableCommand {
	
	struct Options : ParsableArguments {
		
		@ArgumentParser.Option(help: "The id of the Google service to use to do the backup. Required if there are more than one Google service in officectl conf, otherwise the only Google service is used.")
		var serviceId: String?
		
		@ArgumentParser.Option(help: "The path to the config file to use (WILL BE OVERWRITTEN) for offlineimap.")
		var offlineimapConfigFile: String
		
		@ArgumentParser.Option(help: "The maximum number of concurrent sync that will be done by offlineimap.")
		var maxConcurrentAccountSync: Int?
		
		@ArgumentParser.Option(help: "A path to a file in which the offlineimap output will be written.")
		var offlineimapOutput: String?
		
		@ArgumentParser.Option(help: "When downloading emails, if the username of the email has the given suffix, the resulting destination will be the same email without the suffix in the username. The emails to backup given will be searched with and without the suffix.")
		var disabledEmailSuffix: String?
		
		@ArgumentParser.Flag(inversion: .prefixedNo, help: "Whether to archive the backup (create a tar bz2 file and remove the directory).")
		var archive: Bool
		
		@ArgumentParser.Flag(inversion: .prefixedNo, help: "Before archiving, whether to “linkify” the backups (ignored when not archiving). Linkifying consists in scanning the backup for duplicate files and de-duplicating the files by replacing the duplicates with a hard link.")
		var linkify = false
		
		@ArgumentParser.Flag(inversion: .prefixedNo, help: "Ignored when not archiving. If the archive for an email already exists, skip the backup for this email. Otherwise, the existing archive will be overwritten.")
		var skipIfArchiveExists = true
		
		@ArgumentParser.Option(help: "The path in which the archives will be put. Defaults to pwd. Required iif archive is set.")
		var archivesDestinationFolder: String?
		
	}
	
	static var configuration = CommandConfiguration(
		commandName: "mails",
		abstract: "Backup the given mails (or all mails in the given service if none are specified) to a directory.",
		discussion: """
			It is a common practice to rename an email into username.disabled@domain.com when a user is gone
			from the company, in order to free the username and be able to create an alias to username for
			another user in the company.
			The “disabled-email-suffix” option allows you to make officectl aware of such a practice to simplify
			the backup process, and avoid getting an email archive named username.disabled.
			Whenever the suffix is set, "username" and "username"+"suffix" are considered to be the same users.
			You can pass whichever when specifying emails to backup, the destination folder will always be
			"username". Additionally both versions of the email will be searched in the directory when the emails
			to backup are specified. If both versions exist in the directory, an error will be thrown and the
			backup command will fail.
			"""
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@OptionGroup()
	var backupOptions: BackupCommand.Options
	
	@OptionGroup()
	var backupMailOptions: Options
	
	@ArgumentParser.Argument()
	var arguments: [String]
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let officeKitConfig = app.officeKitConfig
		let opQ = try app.services.make(OperationQueue.self)
		
		let googleConfig: GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: backupMailOptions.serviceId)
		_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
		
		let downloadsDestinationFolder = URL(fileURLWithPath: backupOptions.downloadsDestinationFolder, isDirectory: true)
		
		let usersFilter = (arguments.isEmpty ? nil : arguments)?.map{ EmailSrcAndDst(emailStr: $0, disabledUserSuffix: backupMailOptions.disabledEmailSuffix, logger: app.logger) }
		
		let archivesDestinationFolder = backupMailOptions.archivesDestinationFolder
		let archivesDestinationFolderStr = (backupMailOptions.archive ? try nil2throw(archivesDestinationFolder) : nil)
		let archivesDestinationFolderURL = archivesDestinationFolderStr.flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
		
		try app.auditLogger.log(action: "Backing up mails w/ service \(backupMailOptions.serviceId ?? "<inferred service>"), users filter \(usersFilter?.map{ $0.debugDescription }.joined(separator: ",") ?? "<no filter>"), \(backupMailOptions.linkify ? "w/": "w/o") linkification, \(archivesDestinationFolder != nil ? "w/": "w/o") archiving.", source: .cli)
		
		let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		let filteredUsers = try await GoogleUserAndDest.fetchListToBackup(
			googleConfig: googleConfig, googleConnector: googleConnector,
			usersFilter: usersFilter, disabledUserSuffix: self.backupMailOptions.disabledEmailSuffix,
			downloadsDestinationFolder: downloadsDestinationFolder, archiveDestinationFolder: archivesDestinationFolderURL,
			skipIfArchiveFound: self.backupMailOptions.skipIfArchiveExists,
			console: context.console, opQ: opQ
		)
		
		/* Backup given mails */
		let options = BackupMailContext(options: backupMailOptions, console: context.console, mainConnector: googleConnector, users: filteredUsers)
		let op = FetchAllMailsOperation(options: options)
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		await op.startAndWait()
		try throwIfError(op.fetchError)
		let usersAndDests = op.context.users
		
		/* Linkify the backed-up emails */
		if backupMailOptions.linkify && !usersAndDests.isEmpty {
			context.console.info("Optimizing backups size")
			let q = OperationQueue()
			q.maxConcurrentOperationCount = 2 /* No need to spam the hard-drive… */
			let operations = usersAndDests.filter{ self.backupMailOptions.linkify && $0.archiveDestination != nil }.map{ $0.downloadDestination }.compactMap{ url -> LinkifyOperation? in
				do    {return try LinkifyOperation(folderURL: url, stopOnErrors: false)}
				catch {context.console.warning("cannot linkify backup at URL \(url.absoluteString)"); return nil}
			}
			try await app.services.make(OperationQueue.self).addOperationsAndWait(operations)
			operations.forEach{ op in
				if op.errors.count > 0 {
					context.console.warning("got errors when linkifying backup at URL \(op.folderURL.absoluteString):")
					for (url, error) in op.errors {
						context.console.warning("   \(url.absoluteString): \(error)")
					}
				}
			}
		}
		
		/* Compress the backed-up emails */
		if archivesDestinationFolder != nil, !usersAndDests.isEmpty {
			context.console.info("Compressing backups")
			
			let q = OperationQueue()
			q.maxConcurrentOperationCount = 4 /* Seems fair on today’s hardware… */
			let operations = usersAndDests.compactMap{ userAndDest -> TarOperation? in
				return userAndDest.archiveDestination.flatMap{ archiveDestination in
					/* Will create the enclosing folder if not already there (a bit of trivia: the the call don’t fail if the directory already exist). */
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
			try await app.services.make(OperationQueue.self).addOperationsAndWait(operations)
			operations.forEach{ op in
				if let tarError = op.tarError {
					context.console.warning("could not compress \(op.sources.first!): \(tarError)")
				}
				/* We have at most one deletion error because there is only one source.*/
				if let deletionError = op.sourceDeletionErrors.randomElement() {
					context.console.warning("could not delete \(deletionError.key): \(deletionError.value)")
				}
			}
		}
	}
	
	/* ****************************************** */
	
	struct BackupMailContext {
		
		let offlineimapConfigFileURL: URL
		let maxConcurrentSync: Int?
		let offlineimapOutputFileURL: URL?
		
		let console: Console
		
		let mainConnector: GoogleJWTConnector
		let users: [GoogleUserAndDest]
		
		init(options o: BackupMailsCommand.Options, console csl: Console, mainConnector c: GoogleJWTConnector, users u: [GoogleUserAndDest]) {
			offlineimapConfigFileURL = URL(fileURLWithPath: o.offlineimapConfigFile, isDirectory: false)
			maxConcurrentSync = o.maxConcurrentAccountSync
			offlineimapOutputFileURL = o.offlineimapOutput.map{ URL(fileURLWithPath: $0, isDirectory: false) }
			
			console = csl
			
			mainConnector = c
			users = u
		}
		
	}
	
	class FetchAllMailsOperation : RetryingOperation {
		
		let context: BackupMailContext
		
		var fetchError: Error?
		
		init(options o: BackupMailContext) {
			context = o
		}
		
		override var isAsynchronous: Bool {
			return false
		}
		
		override func startBaseOperation(isRetry: Bool) {
			Task{
				do {
					let operation = try await withThrowingTaskGroup(of: (GoogleUserAndDest, String, Date).self, returning: OfflineimapRunOperation.self, body: { group in
						for user in context.users {
							group.addTask{ try await self.futureAccessToken(for: user) }
						}
						
						var info = (tokens: [GoogleUser: (token: String, destination: URL)](), minExpirationDate: Date.distantFuture)
						while let curResult = try await group.next() {
							info.minExpirationDate = min(info.minExpirationDate, curResult.2)
							info.tokens[curResult.0.user] = (curResult.1, curResult.0.downloadDestination)
						}
						return OfflineimapRunOperation(userInfos: info.tokens, tokensMinExpirationDate: info.minExpirationDate, context: self.context)
					})
					
					await operation.startAndWait()
					if let e = operation.runError {throw e}
					baseOperationEnded()
				} catch _ as OfflineimapRunOperation.ConfigExpiredError {
					baseOperationEnded(needsRetryIn: 0)
				} catch {
					fetchError = error
					baseOperationEnded()
				}
			}
		}
		
		private func futureAccessToken(for userAndDest: GoogleUserAndDest) async throws -> (GoogleUserAndDest, String, Date) {
			let scope = Set(arrayLiteral: "https://mail.google.com/")
			let connector = GoogleJWTConnector(from: context.mainConnector, userBehalf: userAndDest.user.primaryEmail.rawValue)
			
			try await connector.connect(scope: scope)
			
			if let token = await connector.token, let expirationDate = await connector.expirationDate {
				return (userAndDest, token, expirationDate)
			} else {
				throw NSError(domain: "com.happn.officectl", code: 42, userInfo: [NSLocalizedDescriptionKey: "Internal error"])
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
		
		init(userInfos i: [GoogleUser: (token: String, destination: URL)], tokensMinExpirationDate date: Date, context: BackupMailContext) {
			userInfos = i
			console = context.console
			configurationFileURL = context.offlineimapConfigFileURL
			offlineimapOutputFileURL = context.offlineimapOutputFileURL
			maxConcurrentOfflineimapSyncTasks = context.maxConcurrentSync
			
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
			
			/* We could use XcodeTools to stream the process output. */
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
			/* We guess in 5 minutes offlineimap will have time to close.
			 * If not, it's no big deal anyway, it will simply not be able to finish whatever it was doing remote side before closing,
			 * but we'll still relaunch it when it finishes. */
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
		
		/**
		 Writes the offlineimap config file in configFileURL and returns the expiration date of the config.
		 
		 - returns: The date after which the configuration file will not be valid anymore (access tokens expired). */
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
			 *    Even on an 8-core machine, offlineimap seems greedy, and I got a “pthread_cond_wait: Resource busy” error with maxsyncaccounts = 8.
			 * About the forced unwrapped below, we know the id is fetched on all the users (checked above). */
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
				 *    - When using Python2 w/ OpenSSL 1.1.1, offlineimap cannot validate Gougle’s certificate.
				 *      We can fix that by forcing using the TLS 1.2 protocol. (youhou) */
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
					remoteuser = \(user.primaryEmail.rawValue)
					oauth2_access_token = \(token)
					sslcacertfile = /usr/local/etc/openssl/cert.pem
					ssl_version = tls1_2
					
					"""
			}.joined(separator: "\n")
			
			try Data(config.utf8).write(to: configurationFileURL)
		}
		
	}
	
}
