/*
 * ExternalDirectoryServiceV1Config.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation

import GenericStorage



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
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let url    = try genericConfig.url(forKey: "url",                             currentKeyPath: domain)
		let secret = try genericConfig.string(forKey: "secret",                       currentKeyPath: domain)
		let suc    = try genericConfig.optionalBool(forKey: "supportsUserCreation",   currentKeyPath: domain) ?? true
		let suu    = try genericConfig.optionalBool(forKey: "supportsUserUpdate",     currentKeyPath: domain) ?? true
		let sud    = try genericConfig.optionalBool(forKey: "supportsUserDeletion",   currentKeyPath: domain) ?? true
		let spc    = try genericConfig.optionalBool(forKey: "supportsPasswordChange", currentKeyPath: domain) ?? true
		
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
