/*
 * backup.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation


class BackupOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		command.fail(statusCode: 1, errorMessage: "Please choose what to backup")
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}


//private func inheritablePreRun(flags: Flags, args: [String]) -> Bool {
//	/* The line below is a workaround for issue #77 of Guaka */
//	guard backupCommand.parent?.inheritablePreRun?(flags, args) ?? true else {return false}
//
//	/* Retrieving the list of users to backup */
//	guard let users = try? rootConfig.superuser.retrieveUsers(using: rootConfig.adminEmail, with: ["happn.fr", "happnambassadeur.com"], contrainedTo: (flags.getString(name: "emails-to-backup")?.components(separatedBy: ",")).flatMap{ Set($0) }, verbose: true) else {
//		rootCommand.fail(statusCode: 1, errorMessage: "Cannot get the list of users")
//	}
//
//	backupConfig = BackupConfig(backedUpUsers: users)
//	return true
//}

/* ***** Config Object ***** */

@available(*, deprecated)
var backupConfig: BackupConfig!

struct BackupConfig {
	
	let backedUpUsers: [User]
	
}
