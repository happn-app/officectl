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
	/* The service provider does not have enough info to do the service
	 * de-duplication. We have to do it in the implementation of this method, and
	 * of all the other *Init protocols. Hence the cachedServices argument. */
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyOfficeKitService?
	
}

/* Implementation of OfficeKitServiceInit */
public extension OfficeKitService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyOfficeKitService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unboxed() else {return nil}
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unboxed() as Self? }).first(where: { $0.config.serviceId == c.serviceId }) {
			return alreadyInstantiated.erased()
		}
		
		return self.init(config: c, globalConfig: gc).erased()
	}
	
}
