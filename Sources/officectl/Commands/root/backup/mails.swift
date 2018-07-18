/*
 * mails.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Darwin
import Foundation

import Guaka
import NIO

import OfficeKit



func backupMails(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	do {
		let userBehalf = f.getString(name: "google-admin-email")!
		let usersFilter = (f.getString(name: "emails-to-backup")?.components(separatedBy: ",")).flatMap{ Set($0) }
		
		let googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
		let f = googleConnector.connect(scope: GoogleUserSearchOperation.searchScopes, asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[GoogleUser]> in
			let searchOp = GoogleUserSearchOperation(searchedDomain: "happn.fr", googleConnector: googleConnector)
			return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.defaultOperationQueue, resultRetriever: { try $0.result.successValueOrThrow() })
		}
		.then{ happnFrUsers -> EventLoopFuture<[GoogleUser]> in
			let searchOp = GoogleUserSearchOperation(searchedDomain: "happnambassadeur.com", googleConnector: googleConnector)
			return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.defaultOperationQueue, resultRetriever: { try happnFrUsers + $0.result.successValueOrThrow() })
		}
		.then{ allUsers -> EventLoopFuture<Void> in
			let promise: EventLoopPromise<Void> = asyncConfig.eventLoop.newPromise()
			asyncConfig.defaultDispatchQueue.async{
				let options = BackupMailOptions(
					queue: asyncConfig.defaultOperationQueue, mainConnector: googleConnector,
					users: allUsers.filter{ usersFilter?.contains($0.primaryEmail.stringValue) ?? true },
					offlineimapConfigFileURL: URL(fileURLWithPath: f.getString(name: "offlineimap-config-file")!, isDirectory: false),
					backupDestinationFolder: URL(fileURLWithPath: f.getString(name: "destination")!, isDirectory: true),
					maxConcurrentSync: f.getInt(name: "max-concurrent-account-sync"),
					offlineimapOutputFileURL: f.getString(name: "offlineimap-output").map{ URL(fileURLWithPath: $0, isDirectory: false) }
				)
				
				do {
					/* Will create the folder if not already there, does not error
					 * out if already there. */
					try FileManager.default.createDirectory(at: options.backupDestinationFolder, withIntermediateDirectories: true, attributes: nil)
					
					let mb = OfflineImapManager(backupMailOptions: options)
					try mb.run()
					
					/* TODO: Linkify the backups? */
					
					promise.succeed(result: ())
				} catch {
					promise.fail(error: error)
				}
			}
			return promise.futureResult
		}
		return f
	} catch {
		return asyncConfig.eventLoop.newFailedFuture(error: error)
	}
}


/* ****************************************** */

private class Nop : NSObject {
	@objc func nop() {}
}

struct BackupMailOptions {
	
	let queue: OperationQueue
	
	let mainConnector: GoogleJWTConnector
	let users: [GoogleUser]
	
	let offlineimapConfigFileURL: URL
	let backupDestinationFolder: URL
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
	
}

/* Modernize this, if possible (futures, etc.) */
class OfflineImapManager {
	
	let queue: OperationQueue
	let mainConnector: GoogleJWTConnector
	
	let users: [GoogleUser]
	let destinationFolderURL: URL
	let configurationFileURL: URL
	
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
	
	private var runLoop: RunLoop!
	
	init(backupMailOptions: BackupMailOptions) {
		queue = backupMailOptions.queue
		mainConnector = backupMailOptions.mainConnector
		users = backupMailOptions.users
		destinationFolderURL = backupMailOptions.backupDestinationFolder
		configurationFileURL = backupMailOptions.offlineimapConfigFileURL
		maxConcurrentSync = backupMailOptions.maxConcurrentSync
		offlineimapOutputFileURL = backupMailOptions.offlineimapOutputFileURL
	}
	
	func run() throws {
		print("Starting mail backup")
		
		runLoop = RunLoop.current
		
		try startNewOfflineimapProcess()
		
		runLoop.add(Port(), forMode: .defaultRunLoopMode) /* Forces the runloop to continue when all timers, etc. are gone. */
		while shouldKeepRunningRunLoop {
			autoreleasepool {
//				print("New Bg RunLoop run")
				_ = runLoop.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.01))
			}
		}
		
		print("Removing offlineimap config file")
		_ = try? FileManager.default.removeItem(at: configurationFileURL)
		
		if let err = endRunError {throw err}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var interrupted = false
	private var shouldKeepRunningRunLoop = true
	
	private var currentOfflineimapProcess: Process? {
		didSet {
			if currentOfflineimapProcess != nil {
				signalNotifObservers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "SigInt"),  object: nil, queue: queue) { [weak self] _ in guard let strongSelf = self else {return}; strongSelf.interrupted = true; if strongSelf.currentOfflineimapProcess?.isRunning ?? false {strongSelf.currentOfflineimapProcess?.interrupt()} })
				signalNotifObservers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "SigTerm"), object: nil, queue: queue) { [weak self] _ in guard let strongSelf = self else {return}; strongSelf.interrupted = true; if strongSelf.currentOfflineimapProcess?.isRunning ?? false {strongSelf.currentOfflineimapProcess?.terminate()} })
				signal(SIGINT)  { _ in print("Received SIGINT");  NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SigInt"),  object: nil) }
				signal(SIGTERM) { _ in print("Received SIGTERM"); NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SigTerm"), object: nil) }
			} else {
				signal(SIGINT,  nil)
				signal(SIGTERM, nil)
				signalNotifObservers.forEach { NotificationCenter.default.removeObserver($0) }
				signalNotifObservers.removeAll()
			}
		}
	}
	
	private var currentOfflineimapOutputPipe: Pipe? {
		didSet {
			if let obs = processDataReceivedObserver {
				NotificationCenter.default.removeObserver(obs)
				processDataReceivedObserver = nil
			}
			
			if let pipe = currentOfflineimapOutputPipe {
				processDataReceivedObserver = NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: nil, queue: queue) { [weak pipe] _ in
					guard let pipe = pipe else {return}
					
					/* TODO: Process the new data. */
					_ = pipe.fileHandleForReading.availableData
					
					pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
				}
				pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
			}
		}
	}
	
	private var processDataReceivedObserver: NSObjectProtocol?
	private var signalNotifObservers = [NSObjectProtocol]()
	
	private var timerConfigExpirationDate: Timer?
	
	private var endRunError: Error?
	
	private func stopRunLoop() {
		print("Stopping runloop")
		shouldKeepRunningRunLoop = false
	}
	
	private func startNewOfflineimapProcess() throws {
		if let t = timerConfigExpirationDate {
			t.invalidate()
			timerConfigExpirationDate = nil
		}
		if let currentProcess = currentOfflineimapProcess {
			currentProcess.terminationHandler = nil
			currentProcess.interrupt()
			currentProcess.waitUntilExit()
			currentOfflineimapProcess = nil
		}
		
		guard !interrupted else {
			stopRunLoop()
			return
		}
		
		/* We guess in 5 minutes offlineimap will have time to close. If not, it's
		 * no big deal anyway, it will simply not be able to finish whatever it
		 * was doing remote side before closing, but we'll still relaunch it when
		 * it finishes. */
		let killDate = max(try updateOfflineimapConfig().addingTimeInterval(-5*60), Date(timeIntervalSinceNow: 5))
		let t = Timer(fire: killDate, interval: 0, repeats: false) { [weak self] _ in
			guard let strongSelf = self else {return}
			
			print("offlineimap config expired! Re-generating and re-launching offlineimap.")
			do    {try strongSelf.startNewOfflineimapProcess()}
			catch {
				strongSelf.endRunError = error
				strongSelf.stopRunLoop()
			}
		}
		runLoop.add(t, forMode: .defaultRunLoopMode)
		timerConfigExpirationDate = t
		
		if let offlineimapOutputFileURL = offlineimapOutputFileURL {
			FileManager.default.createFile(atPath: offlineimapOutputFileURL.path, contents: nil, attributes: nil)
		}
		
		let process = Process()
		let processOutput = try offlineimapOutputFileURL.map{ try FileHandle(forWritingTo: $0) } ?? FileHandle.nullDevice /* Set to Pipe() and uncomment set of currentOfflineimapOutputPipe if we want to parse the data. */
		process.launchPath = "/usr/local/bin/offlineimap"
		process.arguments = ["-c", configurationFileURL.path]
		process.standardInput = FileHandle.nullDevice /* Forces failure of getting user pass from input when auth token expires. */
		process.standardOutput = processOutput
		process.terminationHandler = { p in
//			print("In termination handler")
			self.timerConfigExpirationDate?.invalidate(); self.timerConfigExpirationDate = nil
			self.currentOfflineimapOutputPipe = nil
			self.currentOfflineimapProcess = nil
			
			if p.terminationStatus != 0 {
				self.endRunError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "offlineimap exited with status \(p.terminationStatus)"])
			}
			
			self.stopRunLoop()
		}
		
		currentOfflineimapProcess = process
		processOutput.seekToEndOfFile(); processOutput.write("***** \(Date()): NEW OFFLINEIMAP RUN!\n".data(using: .utf8)!)
//		currentOfflineimapOutputPipe = processOutput as? Pipe
		
		print("Launching offlineimap")
		process.launch()
	}
	
	/** Writes the offlineimap config file in configFileURL and returns the
	expiration date of the config.
	
	- Returns: The date after which the configuration file will not be valid
	anymore (access tokens expired). */
	private func updateOfflineimapConfig() throws -> Date {
		print("Generating config for offlineimap")
		var configExpirationDate = Date.distantFuture
		
		var tokenForUsers = [GoogleUser: String]()
		for user in users {
			guard let (token, expirationDate) = try? retrieveToken(for: user) else {
				print("Skipping user with unretrievable access token: \(user)")
				continue
			}
			tokenForUsers[user] = token
			configExpirationDate = min(configExpirationDate, expirationDate)
		}
		
		guard tokenForUsers.count > 0 else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "No access tokens could be retrieved..."])
		}
		
		var config = ""
		print("[general]", to: &config)
		print("ui = MachineUI", to: &config)
		/* Defaults arbitrarily to 4. Even on an 8-core machine, offlineimap seems greedy, and I got "pthread_cond_wait: Resource busy" with 8 */
		print("maxsyncaccounts = \(maxConcurrentSync ?? 4)", to: &config)
		print("accounts = ", terminator: "", to: &config)
		var first = true
		for (user, _) in tokenForUsers {
			if !first {print(",", terminator: "", to: &config)}
			print("AccountUserID\(user.id)", terminator: "", to: &config)
			first = false
		}
		print("", to: &config)
		print("", to: &config)
		for (user, token) in tokenForUsers {
			print("[Account AccountUserID\(user.id)]", to: &config)
			print("localrepository = LocalRepoID\(user.id)", to: &config)
			print("remoterepository = RemoteRepoID\(user.id)", to: &config)
			print("", to: &config)
			print("[Repository LocalRepoID\(user.id)]", to: &config)
			print("type = Maildir", to: &config)
			print("localfolders = \(URL(fileURLWithPath: user.primaryEmail.stringValue, relativeTo: destinationFolderURL).path)", to: &config)
			print("", to: &config)
			print("[Repository RemoteRepoID\(user.id)]", to: &config)
			print("type = Gmail", to: &config)
			print("readonly = True", to: &config)
			print("remoteuser = \(user.primaryEmail.stringValue)", to: &config)
			print("oauth2_access_token = \(token)", to: &config)
//			print("sslcacertfile = ~/.dummycert_for_python.pem", to: &config) /* The dummycert solution works when using the System Python */
			print("sslcacertfile = /usr/local/etc/openssl/cert.pem", to: &config) /* This is required when using homebrew’s Python (offlineimap uses Python2; should be fine with Python3) */
			print("", to: &config)
		}
		guard let data = config.data(using: .utf8) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot retrieve config as UTF8 data..."])
		}
		try data.write(to: configurationFileURL)
		
		return configExpirationDate
	}
	
	private func retrieveToken(for user: GoogleUser) throws -> (String, Date) {
		let scope = Set(arrayLiteral: "https://mail.google.com/")
		let connector = GoogleJWTConnector(from: mainConnector, userBehalf: user.primaryEmail.stringValue)
		
		var error: Error?
		let semaphore = DispatchSemaphore(value: 0)
		connector.disconnect(handlerQueue: DispatchQueue(label: "Disconnect"), handler: { _ in semaphore.signal() }); semaphore.wait()
		connector.connect(scope: scope, handlerQueue: DispatchQueue(label: "Connect"), handler: { e in error = e; semaphore.signal() }); semaphore.wait()
		
		guard let token = connector.token, let expirationDate = connector.expirationDate else {
			throw error ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error while retrieving token for user \(user.primaryEmail.stringValue)"])
		}
		return (token, expirationDate)
	}
	
}
