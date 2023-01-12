/*
 * DirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/24.
 */

import Foundation

import NIO
import ServiceKit



public protocol DirectoryAuthenticatorService : UserDirectoryService, DirectoryAuthenticatorServiceInit {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(userID: UserType.IDType, challenge: AuthenticationChallenge, using services: Services) async throws -> Bool
	func validateAdminStatus(userID: UserType.IDType, using services: Services) async throws -> Bool
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol DirectoryAuthenticatorServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyDirectoryAuthenticatorService?
	
}

public extension DirectoryAuthenticatorService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyDirectoryAuthenticatorService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unbox() else {return nil}
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unbox() as Self? }).first(where: { $0.config.serviceID == c.serviceID }) {
			return alreadyInstantiated.erase()
		}
		
		return self.init(config: c, globalConfig: gc).erase()
	}
	
}
