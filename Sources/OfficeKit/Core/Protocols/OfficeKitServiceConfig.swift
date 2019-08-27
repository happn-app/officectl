/*
 * OfficeKitServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import GenericStorage



public protocol OfficeKitServiceConfig : OfficeKitServiceConfigInit, Hashable {
	
	/** The provider id for which the config is for. */
	var providerId: String {get}
	
	/** The id of the instance of the provider, e.g. "happn_ldap". Defined by the
	caller.
	
	Restrictions on the id:
	- It **cannot contain a colon** (“:”)
	- It **cannot be equal to “invalid”** (invalid is a reserved name).
	
	You must fail a config init with a serviceId that do not respect these
	requirements. */
	var serviceId: String {get}
	var serviceName: String {get}
	
	/** The priority of the service in case of conflict when mergning objects
	from multiple services. */
	var mergePriority: Int? {get}
	
	init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws
	
}



public protocol OfficeKitServiceConfigInit {
	
	static func erasedConfig(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws -> AnyOfficeKitServiceConfig
	
}

public extension OfficeKitServiceConfig {
	
	static func erasedConfig(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws -> AnyOfficeKitServiceConfig {
		return try self.init(globalConfig: globalConfig, providerId: pId, serviceId: id, serviceName: name, genericConfig: genericConfig, pathsRelativeTo: baseURL).erased()
	}
	
}
