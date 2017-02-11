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
			Flag(longName: "destination-dir", type: String.self, description: "The folder in which the backuped mails will go. There will be one folder per backed account.", required: true)
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	let offlineimapConfigFileURL = URL(fileURLWithPath: flags.getString(name: "offlineimap-config-file")!, isDirectory: false)
	let destinationFolder = URL(fileURLWithPath: flags.getString(name: "destination-dir")!, isDirectory: true)
	backupMail(forUsers: allUsers!, withSuperuser: superuser!, inFolder: destinationFolder, usingConfigurationFile: offlineimapConfigFileURL, fromCommand: backupMailCommand)
}


func backupMail(forUsers users: [User], withSuperuser superuser: Superuser, inFolder destinationFolderURL: URL, usingConfigurationFile configFileURL: URL, fromCommand command: Command) {
	guard users.count > 0 else {return}
	
	do {
		/* Will create the folder if not already there, does not error out if
		 * already there. */
		try FileManager.default.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
		
		let mb = MailBackuper(users: users, superuser: superuser, destinationFolderURL: destinationFolderURL, configurationFileURL: configFileURL)
		try mb.backupMails()
	} catch {
		command.fail(statusCode: 1, errorMessage: "Received error: \(error)")
	}
}



class MailBackuper {
	
	let users: [User]
	let superuser: Superuser
	let destinationFolderURL: URL
	let configurationFileURL: URL
	
	init(users u: [User], superuser su: Superuser, destinationFolderURL dfu: URL, configurationFileURL cfu: URL) {
		users = u
		superuser = su
		destinationFolderURL = dfu
		configurationFileURL = cfu
	}
	
	func backupMails() throws {
		print("Starting mail backup")
		
		try startNewOfflineimapProcess()
		
		var ok = true
		let rl = RunLoop.main
		rl.add(Port(), forMode: .defaultRunLoopMode) /* Forces the runloop to continue when all timers, etc. are gone. */
		while ok {
			autoreleasepool {
//				print("New Bg RunLoop run")
				ok = (shouldKeepRunningRunLoop && rl.run(mode: .defaultRunLoopMode, before: .distantFuture))
				/* I have NO idea.
				 * Without this sleep, it happens (a lot) that killing the
				 * offlineimap process manually (eg. killall -9 python) does not
				 * trigger a new runloop run, even though the termination handler of
				 * the offlineimap process is called. */
				Thread.sleep(forTimeInterval: 0.001)
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
		RunLoop.main.add(Timer(timeInterval: 0, repeats: false, block: {_ in}), forMode: .defaultRunLoopMode)
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
		
		let pipe = Pipe()
		let process = Process()
		process.launchPath = "/usr/local/bin/offlineimap"
		process.arguments = ["-c", configurationFileURL.path]
		process.standardOutput = pipe
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
		currentOfflineimapOutputPipe = pipe
		
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
		print("maxsyncaccounts = \(tokenForUsers.count)", to: &config)
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
