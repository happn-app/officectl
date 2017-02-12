import Guaka
import Darwin
import Foundation

var backupMailCommand = Command(
	usage: "mail", configuration: configuration, run: execute
)


private func configuration(command: Command) {
	command.add(
		flags: [
			Flag(longName: "offlineimap-config-file", type: String.self, description: "The path to the config file to use (WILL BE OVERWRITTEN) for offlineimap.", required: true),
			Flag(longName: "destination-dir", type: String.self, description: "The folder in which the backuped mails will go. There will be one folder per backed account.", required: true),
			Flag(longName: "max-concurrent-account-sync", type: Int.self, description: "The maximum number of concurrent sync that will be done by offlineimap.", required: false),
			Flag(longName: "offlineimap-output", type: String.self, description: "A path to a file in which the offlineimap output will be written.", required: false)
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	let options = BackupMailOptions(
		users: allUsers!, superuser: superuser!,
		offlineimapConfigFileURL: URL(fileURLWithPath: flags.getString(name: "offlineimap-config-file")!, isDirectory: false),
		backupDestinationFolder: URL(fileURLWithPath: flags.getString(name: "destination-dir")!, isDirectory: true),
		maxConcurrentSync: flags.getInt(name: "max-concurrent-account-sync"),
		offlineimapOutputFileURL: flags.getString(name: "offlineimap-output").map{ URL(fileURLWithPath: $0, isDirectory: false) }
	)
	backupMail(options: options, fromCommand: backupMailCommand)
}


struct BackupMailOptions {
	let users: [User]
	let superuser: Superuser
	
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
	func nop() {}
}

class OfflineImapManager {
	
	let users: [User]
	let superuser: Superuser
	let destinationFolderURL: URL
	let configurationFileURL: URL
	
	let maxConcurrentSync: Int?
	let offlineimapOutputFileURL: URL?
	
	init(backupMailOptions: BackupMailOptions) {
		users = backupMailOptions.users
		superuser = backupMailOptions.superuser
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
//		RunLoop.main.add(Timer(timeInterval: 0, repeats: false, block: {_ in print("hello!")}), forMode: .defaultRunLoopMode)
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
		
		let expirationDate = try updateOfflineimapConfig()
		let t = Timer(fire: expirationDate, interval: 0, repeats: false) { [weak self] _ in
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
		process.standardOutput = processOutput
		process.terminationHandler = { p in
//			print("In termination handler")
			self.timerConfigExpirationDate?.invalidate(); self.timerConfigExpirationDate = nil
			self.currentOfflineimapOutputPipe = nil
			self.currentOfflineimapProcess = nil
			
			if p.terminationStatus != 0 {
				self.endRunError = NSError(domain: "ghapp", code: 1, userInfo: [NSLocalizedDescriptionKey: "offlineimap exited with status \(p.terminationStatus)"])
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
		var configExpirationDate = Date(timeIntervalSinceNow: 100 * 365 * 24 * 60 * 60) /* Init with 100 years expiration. Set to min of expiration dates later. */
		
		var tokenForUsers = [User: String]()
		for user in users {
			guard let (token, expirationDate) = try? user.accessToken(forScopes: ["https://mail.google.com/"], withSuperuser: superuser, forceRegeneration: true) else {
				print("Skipping user with unretrievable access token: \(user)")
				continue
			}
			tokenForUsers[user] = token
			configExpirationDate = min(configExpirationDate, expirationDate)
		}
		
		guard tokenForUsers.count > 0 else {
			throw NSError(domain: "ghapp", code: 1, userInfo: [NSLocalizedDescriptionKey: "No access tokens could be retrieved..."])
		}
		
		var config = ""
		print("[general]", to: &config)
		print("ui = MachineUI", to: &config)
		print("maxsyncaccounts = \(maxConcurrentSync ?? 8)", to: &config) /* Defaults arbitrarily to 8 */
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
			print("status_backend = sqlite", to: &config)
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
			print("sslcacertfile = ~/.dummycert_for_python.pem", to: &config)
			print("", to: &config)
		}
		guard let data = config.data(using: .utf8) else {
			throw NSError(domain: "ghapp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot retrieve config as UTF8 data..."])
		}
		try data.write(to: configurationFileURL)
		
		return configExpirationDate
	}
	
}
