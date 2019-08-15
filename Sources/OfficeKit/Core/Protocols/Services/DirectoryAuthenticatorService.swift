/*
 * DirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Vapor



public protocol DirectoryAuthenticatorService : UserDirectoryService, DirectoryAuthenticatorServiceInit {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(userId: UserType.IdType, challenge: AuthenticationChallenge, on container: Container) throws -> EventLoopFuture<Bool>
	func validateAdminStatus(userId: UserType.IdType, on container: Container) throws -> EventLoopFuture<Bool>
	
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
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unbox() as Self? }).first(where: { $0.config.serviceId == c.serviceId }) {
			return alreadyInstantiated.erase()
		}
		
		return self.init(config: c, globalConfig: gc).erase()
	}
	
}
