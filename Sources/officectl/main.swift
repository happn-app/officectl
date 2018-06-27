/*
 * main.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import URLRequestOperation



/* ****** root command ****** */

let rootFlags = [
	Flag(longName: "github-private-key",          type: String.self, description: "The private key to authenticate GitHub.", inheritable: true),
	Flag(longName: "github-app-id",               type: String.self, description: "The app id to use to authenticate GitHub.", inheritable: true),
	Flag(longName: "github-install-id",           type: String.self, description: "The install id to use to authenticate GitHub.", inheritable: true),
	Flag(longName: "google-admin-email",          type: String.self, description: "The email of an admin user in the domain.", inheritable: true),
	Flag(longName: "google-superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", inheritable: true),
	Flag(longName: "happn-refresh-token",         type: String.self, description: "A refresh token to authenticate happn.", inheritable: true)
]

let rootCommand = Command(usage: "officectl", flags: rootFlags, run: { command, flags, args in execute(operation: RootOperation(command: command, flags: flags, arguments: args)) })

/* ****** root sub-commands ****** */

let getTokenFlags = [
	Flag(longName: "scopes", type: String.self, description: "A comma-separated list of scopes.", required: true)
]

let backupFlags = [
	Flag(longName: "destination", type: String.self, description: "The enclosing folder destination for the backup.", required: true, inheritable: true)
]

let devtestCommand   = Command(usage: "devtest",    flags: [],            parent: rootCommand, run: { command, flags, args in execute(operation: DevTestOperation(command: command, flags: flags, arguments: args)) })
let getTokenCommand  = Command(usage: "get-token",  flags: getTokenFlags, parent: rootCommand, run: { command, flags, args in execute(operation: GetTokenOperation(command: command, flags: flags, arguments: args)) })
let listUsersCommand = Command(usage: "list-users", flags: [],            parent: rootCommand, run: { command, flags, args in execute(operation: ListUsersOperation(command: command, flags: flags, arguments: args)) })
let backupCommand    = Command(usage: "backup",     flags: backupFlags,   parent: rootCommand, run: { command, flags, args in execute(operation: BackupOperation(command: command, flags: flags, arguments: args)) })

/* ****** backup sub-commands ****** */

//let backupMailsFlags = [
//	Flag(longName: "emails-to-backup", type: String.self, description: "A comma-separated list of emails to backup. If an email is not in the directory, it is skipped. If not specified, all emails are backed up.", required: false)
//]

let backupGitHubFlags = [
	Flag(longName: "orgname", type: String.self, description: "The organisation name from which to backup the repositories from.", required: true)
]

let backupGitHubCommand  = Command(usage: "github", flags: backupGitHubFlags, parent: backupCommand, run: { command, flags, args in execute(operation: BackupGitHubOperation(command: command, flags: flags, arguments: args)) })

/* ****** devtest sub-commands ****** */

//let backupMailsFlags = [
//	Flag(longName: "emails-to-backup", type: String.self, description: "A comma-separated list of emails to backup. If an email is not in the directory, it is skipped. If not specified, all emails are backed up.", required: false)
//]

let curtestCommand  = Command(usage: "curtest", flags: [], parent: devtestCommand, run: { command, flags, args in execute(operation: CurTestOperation(command: command, flags: flags, arguments: args)) })



/* ****** main ****** */

di.log = nil /* Disable network logs */
rootCommand.execute()

//func setupCommands() {
//	rootCommand.add(subCommand: backupCommand)
//	rootCommand.add(subCommand: devtestCommand)
//	rootCommand.add(subCommand: listusersCommand)
//
//	backupCommand.add(subCommand: backupMailCommand)
//
//	devtestCommand.add(subCommand: devtestCurtestCommand)
//	devtestCommand.add(subCommand: devtestGmailapiCommand)
//	devtestCommand.add(subCommand: devtestGetstaffgroupsCommand)
//	devtestCommand.add(subCommand: devtestGetexternalgroupsCommand)
//	devtestCommand.add(subCommand: devtestGetgroupscontaininggroupsCommand)
//}
