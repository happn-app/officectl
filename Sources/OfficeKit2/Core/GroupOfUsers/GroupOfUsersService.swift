/*
 * GroupOfUsersService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/21.
 */

import Foundation

import ServiceKit



public protocol GroupOfUsersService<UserType> {
	
	associatedtype UserType : User
	associatedtype GroupOfUsersType : GroupOfUsers
	
	/**
	 A known invalid group of users ID.
	 This is the ID a newly locally created group should have. */
	static var invalidGroupOfUsersID: GroupOfUsersType.IDType {get}
	
	func shortDescription(fromGroupOfUsers groupOfUsers: GroupOfUsersType) -> String
	
	func listUsers(inGroupOfUsers groupOfUsers: GroupOfUsersType, using services: Services) async throws -> [UserType]
	func listGroupsOfUsers(containingUser user: UserType, using services: Services) async throws -> [GroupOfUsersType]
	
	var supportsEmbeddedGroupsOfUsers: Bool {get}
	func listGroupsOfUsers(inGroupOfUser groupOfUser: GroupOfUsersType, using services: Services) async throws -> [GroupOfUsersType]
	
}
