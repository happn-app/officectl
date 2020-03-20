/*
 * guaka_config.swift
 * officectl
 *
 * Created by François Lamboley on 07/08/2018.
 */

import Foundation

import Guaka
import OfficeKit
import Vapor



struct GuakaCommandParseResult {
	
	let officectlConfig: OfficectlConfig
	let wrapperCommand: VaporWrapperForGuakaCommand
	
}


/* Not sure we should be passing the app directly. However, Vapor 3 gave access
 * to the container from the CommandContext, but Vapor 4 does not. So we create
 * the VaporWrapperForGuakaCommand with a reference to the app, and give the app
 * to the VaporWrapperForGuakaCommand.Run */
func parse_cli(_ app: Application) -> GuakaCommandParseResult {
	var result: GuakaCommandParseResult?
	let createSetWrapperCommandHandler = { (run: @escaping VaporWrapperForGuakaCommand.Run) -> (_ cmd: Guaka.Command, _ flags: Guaka.Flags, _ args: [String]) -> Void in
		return { (_ cmd: Guaka.Command, _ flags: Guaka.Flags, _ args: [String]) -> Void in
			let officectlConfig: OfficectlConfig
			do    {officectlConfig = try OfficectlConfig(flags: flags)}
			catch {cmd.fail(statusCode: (error as NSError).code, errorMessage: error.legibleLocalizedDescription)}
			
			result = GuakaCommandParseResult(
				officectlConfig: officectlConfig,
				wrapperCommand: VaporWrapperForGuakaCommand(guakaCommand: cmd, guakaFlags: flags, guakaArgs: args, app: app, run: run)
			)
		}
	}
	
	/* ******************
	   MARK: root command
	   ****************** */
	
	let rootFlags = [
		Flag(shortName: "v", longName: "verbose", type: Bool.self, description: "Asks to be more verbose.", required: false, inheritable: true),
		
		Flag(longName: "config-file", type: String.self, description: "The path to an officectl config file. Defaults to ~/.config/officectl/officectl.yaml, then /etc/officectl/officectl.yaml and finally /usr/local/etc/officectl/officectl.yaml.", inheritable: true),
		
		Flag(longName: "no-interactive-console", value: false, description: "Disable interactive console (ncurses or Vapor’s activity console) for commands that have it.", inheritable: true),
		
		Flag(longName: "static-data-dir", type: String.self, description: "The path to the data dir (containing the static resources for officectl).", inheritable: true),
		Flag(longName: "jwt-secret",      type: String.self, description: "The secret to use for generating the JWT tokens.",                          inheritable: true),
	]
	
	let rootCommand = Command(usage: "officectl", flags: rootFlags, run: createSetWrapperCommandHandler(root))
	
	
	/* ***********************
	   MARK: root sub-commands
	   *********************** */
	
	let getTokenFlags = [
		Flag(longName: "scopes",     type: String.self, description: "A comma-separated list of scopes.",                       required: false),
		Flag(longName: "service-id", type: String.self, description: "The id of the service from which to retrieve the token.", required: false)
	]
	
	let listUsersFlags = [
		Flag(longName: "include-suspended-users", value: false,      description: "For the directory services that supports it, do we filter out the suspended users?"),
		Flag(longName: "service-id",              type: String.self, description: "The id of the directory service from which to retrieve the list of users.", required: false)
	]
	
	let backupFlags = [
		Flag(longName: "downloads-destination-folder", type: String.self, description: "The enclosing folder destination for the backup.", required: true, inheritable: true),
	]
	
	let syncFlags = [
		Flag(longName: "from", type: String.self, description: "The source service from which to sync the directories from.",                                  required: true),
		Flag(longName: "to",   type: String.self, description: "The services to which the directory will be synchronized to. This is a comma-separated list.", required: true)
	]
	
	let devtestCommand = Command(usage: "devtest",    flags: [],             parent: rootCommand, run: createSetWrapperCommandHandler(devTest))
	let _              = Command(usage: "get-token",  flags: getTokenFlags,  parent: rootCommand, run: createSetWrapperCommandHandler(getToken))
	let _              = Command(usage: "list-users", flags: listUsersFlags, parent: rootCommand, run: createSetWrapperCommandHandler(listUsers))
	let backupCommand  = Command(usage: "backup",     flags: backupFlags,    parent: rootCommand, run: createSetWrapperCommandHandler(backup))
	let _              = Command(usage: "sync",       flags: syncFlags,      parent: rootCommand, run: createSetWrapperCommandHandler(sync))
	let usersCommand   = Command(usage: "users",      flags: [],             parent: rootCommand, run: createSetWrapperCommandHandler(users))
	let serverCommand  = Command(usage: "server",     flags: [],             parent: rootCommand, run: createSetWrapperCommandHandler(server))
	
	
	/* *************************
	   MARK: backup sub-commands
	   ************************* */
	
	let backupMailsFlags = [
		Flag(longName: "service-id",                   type: String.self, description: "The id of the Google service to use to do the backup. Required if there are more than one Google service in officectl conf, otherwise the only Google service is used.", required: false),
		
		Flag(longName: "offlineimap-config-file",      type: String.self, description: "The path to the config file to use (WILL BE OVERWRITTEN) for offlineimap.", required: true),
		Flag(longName: "max-concurrent-account-sync",  type: Int.self,    description: "The maximum number of concurrent sync that will be done by offlineimap.", required: false),
		Flag(longName: "offlineimap-output",           type: String.self, description: "A path to a file in which the offlineimap output will be written.", required: false),
		
		Flag(longName: "disabled-email-suffix",        type: String.self, description: "When downloading emails, if the username of the email has the given suffix, the resulting destination will be the same email without the suffix in the username. The emails to backup given will be searched with and without the suffix.", required: false),
		
		Flag(longName: "archive",                      value: false,      description: "Whether to archive the backup (create a tar bz2 file and remove the directory)."),
		Flag(longName: "nolinkify",                    value: false,      description: "Before archiving, whether to “linkify” the backups (ignored when not archiving). Linkifying consists in scanning the backup for duplicate files and de-duplicating the files by replacing the duplicates with a hard link."),
		Flag(longName: "no-skip-if-archive-exists",    value: false,      description: "Ignored when not archiving. If the archive for an email already exists, do NOT skip the backup for this email, overwrite the existing archive."),
		Flag(longName: "archives-destination-folder",  type: String.self, description: "The path in which the archives will be put. Defaults to pwd. Required iif archive is set.", required: false)
	]
	
	let backupDriveFlags = [
		Flag(longName: "service-id",                   type: String.self, description: "The id of the Google service to use to do the backup. Required if there are more than one Google service in officectl conf, otherwise the only Google service is used.", required: false),
		
		Flag(longName: "disabled-email-suffix",        type: String.self, description: "When downloading the drive, if the username of the email has the given suffix, the resulting destination will be the same email without the suffix in the username. The drives to backup given will be searched with and without the suffix.", required: false),
		
		Flag(longName: "erase-downloaded-files",       value: false,      description: "Whether to remove the files from the drive after downloading them. If a file is shared it will be also removed! A log file will contain all the shared files that have been removed, with the list of people w/ access to the files."),
		
		Flag(longName: "path-filters",                 type: String.self, description: "Only download files matching the given comma-separated filters. The filters are applied on the full paths of the files. If any path matches (case-insensitive match), the file will be downloaded. The filter is NOT a regex; only a basic case-insensitive string match will be done, however if the filter starts with a ^ the filter will have to match the beginning of the path. It is thus impossible to specify a filter either starting with ^ or containing a comma.", required: false),
		Flag(longName: "skip-other-owner",             value: false,      description: "Do not download files not owned by the user, even if they take quota for the user."),
		Flag(longName: "no-skip-zero-quota-files",     value: false,      description: "Also download files not taking any quota for the user."),
		
		Flag(longName: "archive",                      value: false,      description: "Whether to archive the backup (create a tar bz2 file and remove the directory)."),
		Flag(longName: "no-skip-if-archive-exists",    value: false,      description: "Ignored when not archiving. If the archive for an email already exists, do NOT skip the backup for this email, overwrite the existing archive."),
		Flag(longName: "archives-destination-folder",  type: String.self, description: "The path in which the archives will be put. Defaults to pwd. Required iif archive is set.", required: false)
	]
	
	let backupGitHubFlags = [
		Flag(longName: "orgname",    type: String.self, description: "The organisation name from which to backup the repositories from.", required: true),
		Flag(longName: "service-id", type: String.self, description: "The id of the GitHub service to use to do the backup. Required if there are more than one GitHub service in officectl conf, otherwise the only GitHub service is used.", required: false)
	]
	
	let backupMailsLongHelp = """
	Backup the given mails (or all mails in the given service if none are specified) to a directory.
	
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
	let backupDriveLongHelp = """
	Backup the drive of the given emails (or all mails in the given service if none are specified) to a
	directory.
	
	The “data” files are copied as-is, the “cloud” files are converted to xlsx, pptx and docx. A document
	will be generated to summarize the sync, and list potential data losses (conversion is impossible, etc.)
	
	The “disabled-email-suffix” option exists too, just like for the backup mails action. See the doc of
	the action for more info.
	"""
	let _ = Command(usage: "mails",  shortMessage: "Backup the given mails (or all if none specified)",               longMessage: backupMailsLongHelp, flags: backupMailsFlags,  parent: backupCommand, run: createSetWrapperCommandHandler(backupMails))
	let _ = Command(usage: "drive",  shortMessage: "Backup the drive for the given mails (or all if none specified)", longMessage: backupDriveLongHelp, flags: backupDriveFlags,  parent: backupCommand, run: createSetWrapperCommandHandler(backupDrive))
	let _ = Command(usage: "github",                                                                                                                    flags: backupGitHubFlags, parent: backupCommand, run: createSetWrapperCommandHandler(backupGitHub))
	
	
	/* *************************
	   MARK: users sub-commands
	   ************************* */
	
	let usersCreateFlags = [
		Flag(longName: "email",       type: String.self, description: "The email of the new user (we require the full email to infer the domain for the new user).", required: true),
		Flag(longName: "lastname",    type: String.self, description: "The lastname of the new user.", required: true),
		Flag(longName: "firstname",   type: String.self, description: "The firstname of the new user.", required: true),
		Flag(longName: "password",    type: String.self, description: "The password of the new user. If not set, an auto-generated pass will be used.", required: false),
		Flag(longName: "service-ids", type: String.self, description: "The service ids on which to create the user. If unset, the user will be created on all the services configured.", required: false),
		Flag(longName: "yes",         value: false,      description: "If set, this the users will be created without confirmation.")
	]
	
	let usersChangePasswordFlags = [
		Flag(longName: "user-id",     type: String.self, description: "The tagged user id of the user whose password needs to be reset.", required: true),
		Flag(longName: "service-ids", type: String.self, description: "The service ids on which to reset the password. If unset, the password will be reset on all the services configured.", required: false)
	]
	
	let _ = Command(usage: "create",          flags: usersCreateFlags,         parent: usersCommand, run: createSetWrapperCommandHandler(usersCreate))
	let _ = Command(usage: "change-password", flags: usersChangePasswordFlags, parent: usersCommand, run: createSetWrapperCommandHandler(usersChangePassword))
	
	
	/* *************************
	   MARK: server sub-commands
	   ************************* */
	
	let serverServeFlags = [
		Flag(shortName: "H", longName: "hostname", type: String.self, description: "Set the hostname the server will run on. Defaults to localhost."),
		Flag(shortName: "p", longName: "port",     type: Int.self,    description: "Set the port the server will run on. Defaults to 8080.")
//		Flag(shortName: "b", longName: "bind",     type: String.self, description: "Convenience for setting hostname and port together. The hostname and port options have precedence over this option.", required: false)
	]
	
	let _ = Command(usage: "serve",  flags: serverServeFlags, parent: serverCommand, run: createSetWrapperCommandHandler(serverServe))
	let _ = Command(usage: "routes", flags: [],               parent: serverCommand, run: createSetWrapperCommandHandler(serverRoutes))
	
	
	/* **************************
	   MARK: devtest sub-commands
	   ************************** */
	
	let _ = Command(usage: "curtest", flags: [], parent: devtestCommand, run: createSetWrapperCommandHandler(curTest))
	let _ = Command(usage: "consoleperm email group", flags: [], parent: devtestCommand, run: createSetWrapperCommandHandler(consolePerm))
	
	
	
	rootCommand.execute()
	guard let resultNonOptional = result else {rootCommand.fail(statusCode: 1)}
	return resultNonOptional
}
