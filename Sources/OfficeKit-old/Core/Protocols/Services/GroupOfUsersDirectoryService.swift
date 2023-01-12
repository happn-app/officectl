/*
 * GroupOfUsersDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/24.
 */

import Foundation

import GenericJSON
import NIO
import ServiceKit



public protocol GroupOfUsersDirectoryService : UserDirectoryService, GroupOfUsersDirectoryServiceInit {
	
	associatedtype GroupType : DirectoryGroup
	
	func shortDescription(fromGroup group: GroupType) -> String
	
	func listUsers(inGroup group: GroupType, using services: Services) async throws -> [UserType]
	func listGroups(withUser user: UserType, using services: Services) async throws -> [GroupType]
	
	var supportsEmbeddedGroupsOfUsers: Bool {get}
	func listGroups(inGroup group: GroupType, using services: Services) async throws -> [GroupType]
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol GroupOfUsersDirectoryServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyGroupOfUsersDirectoryService?
	
}

public extension GroupOfUsersDirectoryService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyGroupOfUsersDirectoryService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unbox() else {return nil}
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unbox() as Self? }).first(where: { $0.config.serviceID == c.serviceID }) {
			return alreadyInstantiated.erase()
		}
		
		return self.init(config: c, globalConfig: gc).erase()
	}
	
}
