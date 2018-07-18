/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import Guaka
import NIO
import URLRequestOperation

import OfficeKit



func configure() -> Command {
	di.log = nil /* Disable network logs */
	
	let asyncConfig = AsyncConfig(eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1), defaultDispatchQueue: DispatchQueue(label: "Default Background Dispatch Queue"), defaultOperationQueue: OperationQueue())
	
	/* ******************
	   MARK: root command
	   ****************** */
	
	let rootFlags = [
		Flag(longName: "github-private-key",          type: String.self, description: "The private key to authenticate GitHub.", inheritable: true),
		Flag(longName: "github-app-id",               type: String.self, description: "The app id to use to authenticate GitHub.", inheritable: true),
		Flag(longName: "github-install-id",           type: String.self, description: "The install id to use to authenticate GitHub.", inheritable: true),
		Flag(longName: "google-admin-email",          type: String.self, description: "The email of an admin user in the domain.", inheritable: true),
		Flag(longName: "google-superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", inheritable: true),
		Flag(longName: "happn-refresh-token",         type: String.self, description: "A refresh token to authenticate happn.", inheritable: true)
	]
	
	let rootCommand = Command(usage: "officectl", flags: rootFlags, run: { command, flags, args in execute(command: command, with: root(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	
	
	/* ***********************
	   MARK: root sub-commands
	   *********************** */
	
	let getTokenFlags = [
		Flag(longName: "scopes", type: String.self, description: "A comma-separated list of scopes.", required: true)
	]
	
	let backupFlags = [
		Flag(longName: "destination", type: String.self, description: "The enclosing folder destination for the backup.", required: true, inheritable: true)
	]
	
	let syncFlags = [
		Flag(longName: "from", type: String.self, description: "The source service from which to sync the directories from.", required: true),
		Flag(longName: "to",   type: String.self, description: "The services to which the directory will be synchronized to. This is a comma-separated list.", required: true)
	]
	
	let devtestCommand = Command(usage: "devtest",    flags: [],            parent: rootCommand, run: { command, flags, args in execute(command: command, with: devTest(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	let _              = Command(usage: "get-token",  flags: getTokenFlags, parent: rootCommand, run: { command, flags, args in execute(command: command, with: getToken(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	let _              = Command(usage: "list-users", flags: [],            parent: rootCommand, run: { command, flags, args in execute(command: command, with: listUsers(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	let backupCommand  = Command(usage: "backup",     flags: backupFlags,   parent: rootCommand, run: { command, flags, args in execute(command: command, with: backup(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	let _              = Command(usage: "sync",       flags: syncFlags,     parent: rootCommand, run: { command, flags, args in execute(command: command, with: sync(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	
	
	/* *************************
	   MARK: backup sub-commands
	   ************************* */
	
	let backupMailsFlags = [
		Flag(longName: "emails-to-backup",            type: String.self, description: "A comma-separated list of emails to backup. If an email is not in the directory, it is skipped. If not specified, all emails are backed up.", required: false),
		Flag(longName: "offlineimap-config-file",     type: String.self, description: "The path to the config file to use (WILL BE OVERWRITTEN) for offlineimap.", required: true),
		Flag(longName: "max-concurrent-account-sync", type: Int.self,    description: "The maximum number of concurrent sync that will be done by offlineimap.", required: false),
		Flag(longName: "offlineimap-output",          type: String.self, description: "A path to a file in which the offlineimap output will be written.", required: false)
	]
	
	let backupGitHubFlags = [
		Flag(longName: "orgname", type: String.self, description: "The organisation name from which to backup the repositories from.", required: true)
	]
	
	let _ = Command(usage: "mails",  flags: backupMailsFlags,  parent: backupCommand, run: { command, flags, args in execute(command: command, with: backupMails(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	let _ = Command(usage: "github", flags: backupGitHubFlags, parent: backupCommand, run: { command, flags, args in execute(command: command, with: backupGitHub(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	
	
	/* **************************
	   MARK: devtest sub-commands
	   ************************** */
	
	let _ = Command(usage: "curtest", flags: [], parent: devtestCommand, run: { command, flags, args in execute(command: command, with: curTest(flags: flags, arguments: args, asyncConfig: asyncConfig)) })
	
	return rootCommand
}
