/*
 * routes.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import OfficeKit
import Vapor



func routes(_ r: inout Routes, _ c: Container) throws {
	let openDirectoryService: OpenDirectoryService = try c.make()
	
	let userSearchController = UserSearchController(openDirectoryService: openDirectoryService, container: c)
	r.post("existing-user-from", "persistent-id", use: userSearchController.fromPersistentId)
	r.post("existing-user-from", "user-id",       use: userSearchController.fromUserId)
	r.get("list-all-users",                       use: userSearchController.listAllUsers)
	
	let userController = UserController(openDirectoryService: openDirectoryService, container: c)
	r.post("create-user",     use: userController.createUser)
	r.post("update-user",     use: userController.updateUser)
	r.post("delete-user",     use: userController.deleteUser)
	r.post("change-password", use: userController.changePassword)
}
