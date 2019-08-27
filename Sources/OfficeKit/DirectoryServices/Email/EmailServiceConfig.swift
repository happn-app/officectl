/*
 * EmailServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/08/2019.
 */

import Foundation

import GenericStorage



public struct EmailServiceConfig : OfficeKitServiceConfig {
	
	public var global: GlobalConfig
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public init(globalConfig gcfg: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		global = gcfg
		
		precondition(id != "invalid" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		mergePriority = nil
	}
	
}
