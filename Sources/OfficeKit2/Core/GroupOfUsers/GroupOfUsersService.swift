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
	
	func shortDescription(fromGroupOfUsers groupOfUsers: GroupOfUsersType) -> String
	
	func string(fromGroupOfUsersID groupOfUsersID: GroupOfUsersType.GroupOfUsersIDType) -> String
	func groupOfUsersID(fromString string: String) throws -> GroupOfUsersType.GroupOfUsersIDType
	
	func string(fromPersistentGroupOfUsersID pID: GroupOfUsersType.PersistentGroupOfUsersIDType) -> String
	func persistentGroupOfUsersID(fromString string: String) throws -> GroupOfUsersType.PersistentGroupOfUsersIDType
	
	func listUsers(inGroupOfUsers groupOfUsers: GroupOfUsersType, using services: Services) async throws -> [UserType]
	func listGroupsOfUsers(containingUser user: UserType, using services: Services) async throws -> [GroupOfUsersType]
	
	var supportsEmbeddedGroupsOfUsers: Bool {get}
	func listGroupsOfUsers(inGroupOfUser groupOfUser: GroupOfUsersType, using services: Services) async throws -> [GroupOfUsersType]
	
}


public extension Dictionary where Key == HashableGroupOfUsersService {
	
	subscript(_ service: any GroupOfUsersService) -> Value? {
		get {self[.init(value: service, valueID: service.id)]}
		set {self[.init(value: service, valueID: service.id)] = newValue}
	}
	
}
