/*
 * guaka_config.swift
 * officectl
 *
 * Created by François Lamboley on 07/08/2018.
 */

import Foundation

import Guaka
import Vapor



func get_guaka_command() -> VaporWrapperForGuakaCommand {
	var wrapperCommand: VaporWrapperForGuakaCommand?
	let createSetWrapperCommandHandler = { (run: @escaping VaporWrapperForGuakaCommand.Run) -> (_ cmd: Guaka.Command, _ flags: Guaka.Flags, _ args: [String]) -> Void in
		return { wrapperCommand = VaporWrapperForGuakaCommand(guakaCommand: $0, guakaFlags: $1, guakaArgs: $2, run: run) }
	}
	
	/* ******************
	   MARK: root command
	   ****************** */
	
	let rootFlags = [
		Flag(longName: "ldap-host",                   type: String.self, description: "The host of the LDAP. LDAP server is expected to be communicating with LDAPv3.", inheritable: true),
		Flag(longName: "ldap-admin-username",         type: String.self, description: "The admin username to connect to the LDAP.", inheritable: true),
		Flag(longName: "ldap-admin-password",         type: String.self, description: "The admin password to connect to the LDAP.", inheritable: true),
		Flag(longName: "github-private-key",          type: String.self, description: "The private key to authenticate GitHub.", inheritable: true),
		Flag(longName: "github-app-id",               type: String.self, description: "The app id to use to authenticate GitHub.", inheritable: true),
		Flag(longName: "github-install-id",           type: String.self, description: "The install id to use to authenticate GitHub.", inheritable: true),
		Flag(longName: "google-admin-email",          type: String.self, description: "The email of an admin user in the domain.", inheritable: true),
		Flag(longName: "google-superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", inheritable: true),
		Flag(longName: "happn-refresh-token",         type: String.self, description: "A refresh token to authenticate happn.", inheritable: true)
	]
	
	let rootCommand = Command(usage: "officectl", flags: rootFlags, run: createSetWrapperCommandHandler(root))
	
	
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
	
	let devtestCommand = Command(usage: "devtest",    flags: [],            parent: rootCommand, run: createSetWrapperCommandHandler(devTest))
	let _              = Command(usage: "get-token",  flags: getTokenFlags, parent: rootCommand, run: createSetWrapperCommandHandler(getToken))
	let _              = Command(usage: "list-users", flags: [],            parent: rootCommand, run: createSetWrapperCommandHandler(listUsers))
	let backupCommand  = Command(usage: "backup",     flags: backupFlags,   parent: rootCommand, run: createSetWrapperCommandHandler(backup))
	let _              = Command(usage: "sync",       flags: syncFlags,     parent: rootCommand, run: createSetWrapperCommandHandler(sync))
	let serverCommand  = Command(usage: "server",     flags: [],            parent: rootCommand, run: createSetWrapperCommandHandler(server))
	
	
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
	
	let _ = Command(usage: "mails",  flags: backupMailsFlags,  parent: backupCommand, run: createSetWrapperCommandHandler(backupMails))
	let _ = Command(usage: "github", flags: backupGitHubFlags, parent: backupCommand, run: createSetWrapperCommandHandler(backupGitHub))
	
	
	/* *************************
	   MARK: server sub-commands
	   ************************* */
	
	let _ = Command(usage: "serve",  flags: [], parent: serverCommand, run: createSetWrapperCommandHandler(serverServe))
	let _ = Command(usage: "routes", flags: [], parent: serverCommand, run: createSetWrapperCommandHandler(serverRoutes))
	
	
	/* **************************
	   MARK: devtest sub-commands
	   ************************** */
	
	let _ = Command(usage: "curtest", flags: [], parent: devtestCommand, run: createSetWrapperCommandHandler(curTest))
	
	
	
	rootCommand.execute()
	guard let wrapperCommandNonOptional = wrapperCommand else {rootCommand.fail(statusCode: 1)}
	return wrapperCommandNonOptional
}