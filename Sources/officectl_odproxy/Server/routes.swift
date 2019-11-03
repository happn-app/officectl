/*
 * routes.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import OfficeKit
import Vapor



func routes(_ app: Application) throws {
	let openDirectoryService: OpenDirectoryService = app.make()
	
	let userSearchController = UserSearchController(openDirectoryService: openDirectoryService)
	app.post("existing-user-from", "persistent-id", use: userSearchController.fromPersistentId)
	app.post("existing-user-from", "user-id",       use: userSearchController.fromUserId)
	app.get("list-all-users",                       use: userSearchController.listAllUsers)
	
	let userController = UserController(openDirectoryService: openDirectoryService)
	app.post("create-user",     use: userController.createUser)
	app.post("update-user",     use: userController.updateUser)
	app.post("delete-user",     use: userController.deleteUser)
	app.post("change-password", use: userController.changePassword)
}
