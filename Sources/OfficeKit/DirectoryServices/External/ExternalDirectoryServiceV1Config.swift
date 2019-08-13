/*
 * ExternalDirectoryServiceV1Config.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation



public struct ExternalDirectoryServiceV1Config : OfficeKitServiceConfig {
	
	public var global: GlobalConfig
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var url: URL
	public var secret: Data
	
	public var supportsUserCreation: Bool
	public var supportsUserUpdate: Bool
	public var supportsUserDeletion: Bool
	public var supportsPasswordChange: Bool
	
	public init(
		globalConfig: GlobalConfig,
		providerId pId: String, serviceId id: String, serviceName name: String,
		url theURL: URL, secret s: Data,
		supportsUserCreation suc: Bool,
		supportsUserUpdate suu: Bool,
		supportsUserDeletion sud: Bool,
		supportsPasswordChange spc: Bool
	) {
		global = globalConfig
		
		precondition(id != "invalid" && id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		url = theURL
		secret = s
		
		supportsUserCreation = suc
		supportsUserUpdate = suu
		supportsUserDeletion = sud
		supportsPasswordChange = spc
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "External Directory Service V1"
		let url    = try genericConfig.url(for: "url",                             domain: domain)
		let secret = try genericConfig.string(for: "secret",                       domain: domain)
		let suc    = try genericConfig.optionalBool(for: "supportsUserCreation",   domain: domain) ?? true
		let suu    = try genericConfig.optionalBool(for: "supportsUserUpdate",     domain: domain) ?? true
		let sud    = try genericConfig.optionalBool(for: "supportsUserDeletion",   domain: domain) ?? true
		let spc    = try genericConfig.optionalBool(for: "supportsPasswordChange", domain: domain) ?? true
		
		self.init(
			globalConfig: globalConfig,
			providerId: pId, serviceId: id, serviceName: name,
			url: url, secret: Data(secret.utf8),
			supportsUserCreation: suc,
			supportsUserUpdate: suu,
			supportsUserDeletion: sud,
			supportsPasswordChange: spc
		)
	}
	
}
