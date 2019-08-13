/*
 * setup_routes.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import Vapor



func setup_routes(_ router: Router) throws {
	let userSearchController = UserSearchController()
	router.post("existing-user-from", "persistent-id", use: userSearchController.fromPersistentId)
	router.post("existing-user-from", "user-id",       use: userSearchController.fromUserId)
	router.get("list-all-users",                       use: userSearchController.listAllUsers)
	
	let userController = UserController()
	router.post("create-user",     use: userController.createUser)
	router.post("update-user",     use: userController.updateUser)
	router.post("delete-user",     use: userController.deleteUser)
	router.post("change-password", use: userController.changePassword)
}
