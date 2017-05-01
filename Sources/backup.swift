import Guaka
import Foundation


var backupConfig: BackupConfig!
let backupCommand = Command(
	usage: "backup", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
			Flag(longName: "emails-to-backup", type: String.self, description: "A comma-separated list of emails to backup. If an email is not in the directory, it is skipped. If not specified, all emails are backed up.", required: false, inheritable: true)
		]
	)
	command.inheritablePreRun = inheritablePreRun
}

private func inheritablePreRun(flags: Flags, args: [String]) -> Bool {
	/* The line below is a workaround for issue #77 of Guaka */
	guard backupCommand.parent?.inheritablePreRun?(flags, args) ?? true else {return false}
	
	/* Retrieving the list of users to backup */
	guard let users = try? rootConfig.superuser.retrieveUsers(using: rootConfig.adminEmail, with: ["happn.fr", "happnambassadeur.com"], contrainedTo: (flags.getString(name: "emails-to-backup")?.components(separatedBy: ",")).flatMap{ Set($0) }, verbose: true) else {
		rootCommand.fail(statusCode: 1, errorMessage: "Cannot get the list of users")
	}
	
	backupConfig = BackupConfig(backedUpUsers: users)
	return true
}

private func execute(flags: Flags, args: [String]) {
	rootCommand.fail(statusCode: 1, errorMessage: "Please choose what to backup")
}


/* ***** Config Object ***** */

struct BackupConfig {
	
	let backedUpUsers: [User]
	
}
