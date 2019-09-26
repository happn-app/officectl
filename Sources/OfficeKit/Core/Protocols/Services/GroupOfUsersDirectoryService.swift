/*
 * GroupOfUsersDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/09/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



public protocol GroupOfUsersDirectoryService : UserDirectoryService, GroupOfUsersDirectoryServiceInit {
	
	associatedtype GroupType : DirectoryGroup
	
	func shortDescription(fromGroup group: GroupType) -> String
	
	func listUsers(inGroup group: GroupType, on container: Container) throws -> EventLoopFuture<[UserType]>
	func listGroups(inGroup group: GroupType, on container: Container) throws -> EventLoopFuture<[GroupType]>
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol GroupOfUsersDirectoryServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyGroupOfUsersDirectoryService?
	
}

public extension GroupOfUsersDirectoryService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyGroupOfUsersDirectoryService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unboxed() else {return nil}
		return self.init(config: c, globalConfig: gc).erased()
	}
	
}
