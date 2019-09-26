/*
 * DirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Async
import Service



public protocol DirectoryAuthenticatorService : UserDirectoryService, DirectoryAuthenticatorServiceInit {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(userId: UserType.IdType, challenge: AuthenticationChallenge, on container: Container) throws -> Future<Bool>
	func validateAdminStatus(userId: UserType.IdType, on container: Container) throws -> Future<Bool>
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol DirectoryAuthenticatorServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyDirectoryAuthenticatorService?
	
}

public extension DirectoryAuthenticatorService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyDirectoryAuthenticatorService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unboxed() else {return nil}
		return self.init(config: c, globalConfig: gc).erased()
	}
	
}
