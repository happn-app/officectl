/*
 * mails.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Darwin
import Foundation

import OfficeKit



class BackupMailsOperation : CommandOperation {
	
	let googleConnectorOperation: GetConnectedGoogleConnector
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		do {
			let scopes = f.getString(name: "scopes")!
			let userBehalf = f.getString(name: "google-admin-email")!
			googleConnectorOperation = try GetConnectedGoogleConnector(flags: f, scope: Set(scopes.components(separatedBy: ",")), userBehalf: userBehalf)
		} catch {
			c.fail(statusCode: (error as NSError).code, errorMessage: error.localizedDescription)
		}
		
		super.init(command: c, flags: f, arguments: args)
//	let options = BackupMailOptions(
//		users: backupConfig.backedUpUsers, superuser: rootConfig.superuser,
//		offlineimapConfigFileURL: URL(fileURLWithPath: flags.getString(name: "offlineimap-config-file")!, isDirectory: false),
//		backupDestinationFolder: URL(fileURLWithPath: flags.getString(name: "destination")!, isDirectory: true),
//		maxConcurrentSync: flags.getInt(name: "max-concurrent-account-sync"),
//		offlineimapOutputFileURL: flags.getString(name: "offlineimap-output").map{ URL(fileURLWithPath: $0, isDirectory: false) }
//	)
//	backupMail(options: options, fromCommand: backupMailCommand)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		/* Let's make sure we have a connected Google connector */
		if let e = googleConnectorOperation.connectionError as NSError? {
			command.fail(statusCode: e.code, errorMessage: e.localizedDescription)
		}
		
		print("hello")
		baseOperationEnded()
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}


/* ****************************************** */

struct BackupMailOptions {
	let users: [User]
	
	let offlineimapConfigFileURL: URL
	let backupDestinationFolder: URL
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
}

func backupMail(options: BackupMailOptions, fromCommand command: Command) {
	guard options.users.count > 0 else {return}
	
	do {
		/* Will create the folder if not already there, does not error out if
		 * already there. */
		try FileManager.default.createDirectory(at: options.backupDestinationFolder, withIntermediateDirectories: true, attributes: nil)
		
		let mb = OfflineImapManager(backupMailOptions: options)
		try mb.run()
		
		/* TODO: Linkify the backups? */
	} catch {
		command.fail(statusCode: 1, errorMessage: "Received error: \(error)")
	}
}



private class Nop : NSObject {
	@objc func nop() {}
}

class OfflineImapManager {
	
	let users: [User]
	let destinationFolderURL: URL
	let configurationFileURL: URL
	
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
	
	init(backupMailOptions: BackupMailOptions) {
		users = backupMailOptions.users
		destinationFolderURL = backupMailOptions.backupDestinationFolder
		configurationFileURL = backupMailOptions.offlineimapConfigFileURL
		maxConcurrentSync = backupMailOptions.maxConcurrentSync
		offlineimapOutputFileURL = backupMailOptions.offlineimapOutputFileURL
	}
	
	func run() throws {
		print("Starting mail backup")
		
		try startNewOfflineimapProcess()
		
		var ok = true
		let rl = RunLoop.main
		rl.add(Port(), forMode: .defaultRunLoopMode) /* Forces the runloop to continue when all timers, etc. are gone. */
		while ok {
			autoreleasepool {
//				print("New Bg RunLoop run")
				ok = (shouldKeepRunningRunLoop && rl.run(mode: .defaultRunLoopMode, before: .distantFuture))
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
				signalNotifObservers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "SigInt"),  object: nil, queue: OperationQueue.main) { [weak self] _ in guard let strongSelf = self else {return}; strongSelf.interrupted = true; if strongSelf.currentOfflineimapProcess?.isRunning ?? false {strongSelf.currentOfflineimapProcess?.interrupt()} })
				signalNotifObservers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "SigTerm"), object: nil, queue: OperationQueue.main) { [weak self] _ in guard let strongSelf = self else {return}; strongSelf.interrupted = true; if strongSelf.currentOfflineimapProcess?.isRunning ?? false {strongSelf.currentOfflineimapProcess?.terminate()} })
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
				processDataReceivedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: nil, queue: OperationQueue.main) { [weak pipe] _ in
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
		/* Force trigger a new runloop event to get out. */
		Nop().perform(#selector(Nop.nop), with: nil, afterDelay: 0)
		/* Apparently triggering a new runloop event with a block Timer does not work... */
//		RunLoop.main.add(Timer(timeInterval: 0, repeats: false, block: { _ in print("hello!") }), forMode: .defaultRunLoopMode)
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
		RunLoop.current.add(t, forMode: .defaultRunLoopMode)
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
		
		var tokenForUsers = [User: String]()
		for user in users {
			guard let (token, expirationDate) = try? user.accessToken(forScopes: ["https://mail.google.com/"], withSuperuser: NSNull(), forceRegeneration: true) else {
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
			print("localfolders = \(URL(fileURLWithPath: user.email, relativeTo: destinationFolderURL).path)", to: &config)
			print("", to: &config)
			print("[Repository RemoteRepoID\(user.id)]", to: &config)
			print("type = Gmail", to: &config)
			print("readonly = True", to: &config)
			print("remoteuser = \(user.email)", to: &config)
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
	
}
