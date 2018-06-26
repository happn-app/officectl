/*
 * main.swift
 * ghapp
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import URLRequestOperation

/* ************* */

/*URLRequestOperation.*/di.log = nil

/* ************* */

let rootFlags = [
	Flag(longName: "admin-email", type: String.self, description: "The email of an admin user in the domain.", required: true, inheritable: true),
	Flag(longName: "superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", required: true, inheritable: true)
]

let getTokenFlags = [
	Flag(longName: "scopes", type: String.self, description: "A comma-separated list of scopes.", required: true)
]

/* ************* */

let rootCommand = Command(usage: "ghapp", flags: rootFlags, run: { command, flags, args in execute(operation: RootOperation(command: command, flags: flags, arguments: args)) })

let root_getTokenCommand  = Command(usage: "get-token",  flags: getTokenFlags, run: { command, flags, args in execute(operation: GetTokenOperation(command: command, flags: flags, arguments: args)) })
let root_listUsersCommand = Command(usage: "list-users", flags: [],            run: { command, flags, args in execute(operation: ListUsersOperation(command: command, flags: flags, arguments: args)) })

rootCommand.add(subCommand: root_getTokenCommand)
rootCommand.add(subCommand: root_listUsersCommand)

/* ************* */

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
