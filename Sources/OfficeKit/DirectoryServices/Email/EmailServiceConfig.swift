/*
 * EmailServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/26.
 */

import Foundation

import GenericStorage



public struct EmailServiceConfig : OfficeKitServiceConfig {
	
	public var providerID: String
	public let isHelperService = true
	
	public var serviceID: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		precondition(id != "invalid" && !id.contains(":"))
		providerID = pID
		serviceID = id
		serviceName = name
		
		mergePriority = p
	}
	
}
