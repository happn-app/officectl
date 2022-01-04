/*
 * OfficeKitServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/24.
 */

import Foundation

import GenericStorage



public protocol OfficeKitServiceConfig : OfficeKitServiceConfigInit, Hashable {
	
	/** The provider ID for which the config is for. */
	var providerID: String {get}
	
	/**
	 If `true`, the service won’t be included in the list of all the services by the service provider.
	 It will still be returned if explicitly fetched, either by ID or by type. */
	var isHelperService: Bool {get}
	
	/**
	 The ID of the instance of the provider, e.g. `happn_ldap`.
	 Defined by the caller.
	 
	 Restrictions on the ID:
	 - It **cannot contain a colon** (`:`)
	 - It **cannot be equal to “invalid”** (invalid is a reserved name).
	 
	 You must fail a config init with a serviceID that do not respect these requirements. */
	var serviceID: String {get}
	var serviceName: String {get}
	
	/** The priority of the service in case of conflict when mergning objects from multiple services. */
	var mergePriority: Int? {get}
	
	init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws
	
}



public protocol OfficeKitServiceConfigInit {
	
	static func erasedConfig(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws -> AnyOfficeKitServiceConfig
	
}

public extension OfficeKitServiceConfig {
	
	static func erasedConfig(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws -> AnyOfficeKitServiceConfig {
		return try self.init(providerID: pID, serviceID: id, serviceName: name, mergePriority: p, keyedConfig: keyedConfig, pathsRelativeTo: baseURL).erase()
	}
	
}
