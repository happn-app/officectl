/*
 * GroupOfUsersDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/09/2019.
 */

import Foundation

import GenericJSON
import Vapor



public protocol GroupOfUsersDirectoryService : UserDirectoryService, GroupOfUsersDirectoryServiceInit {
	
	associatedtype GroupType : DirectoryGroup
	
	func shortDescription(fromGroup group: GroupType) -> String
	
	func listUsers(inGroup group: GroupType, on container: Container) throws -> EventLoopFuture<[UserType]>
	
	var supportsEmbeddedGroupsOfUsers: Bool {get}
	func listGroups(inGroup group: GroupType, on container: Container) throws -> EventLoopFuture<[GroupType]>
	
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
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unbox() as Self? }).first(where: { $0.config.serviceId == c.serviceId }) {
			return alreadyInstantiated.erase()
		}
		
		return self.init(config: c, globalConfig: gc).erase()
	}
	
}
