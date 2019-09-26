/*
 * OfficeKitService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/09/2019.
 */

import Foundation



public protocol OfficeKitService : class, Hashable, OfficeKitServiceInit {
	
	/** The id of the linked provider, e.g. "internal_openldap". External
	provider ids (not built-in OfficeKit) must not have the “internal_” prefix. */
	static var providerId: String {get}
	
	associatedtype ConfigType : OfficeKitServiceConfig
	
	var config: ConfigType {get}
	var globalConfig: GlobalConfig {get}
	
	init(config c: ConfigType, globalConfig gc: GlobalConfig)
	
}


extension OfficeKitService {
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.config.serviceId == rhs.config.serviceId
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(config.serviceId)
	}
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol OfficeKitServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyOfficeKitService?
	
}

public extension OfficeKitService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyOfficeKitService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unboxed() else {return nil}
		return self.init(config: c, globalConfig: gc).erased()
	}
	
}
