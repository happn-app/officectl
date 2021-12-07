/*
 * EmailServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/08/2019.
 */

import Foundation

import GenericStorage



public struct EmailServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	public let isHelperService = true
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		precondition(id != "invalid" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		mergePriority = p
	}
	
}
