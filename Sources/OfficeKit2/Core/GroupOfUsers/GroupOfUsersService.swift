/*
 * GroupOfUsersService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/21.
 */

import Foundation

import ServiceKit



public typealias HashableGroupOfUsersService = DeportedHashability<any GroupOfUsersService>

public protocol GroupOfUsersService<UserType> : OfficeService {
	
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


public extension Dictionary where Key == DeportedHashability<any GroupOfUsersService> {
	
	subscript(_ service: any GroupOfUsersService) -> Value? {
		get {self[.init(value: service, valueID: service.id)]}
		set {self[.init(value: service, valueID: service.id)] = newValue}
	}
	
}
