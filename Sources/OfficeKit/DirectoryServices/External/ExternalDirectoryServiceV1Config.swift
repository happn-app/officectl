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
	
	public var mergePriority: Int?
	
	public var url: URL
	public var secret: Data
	
	public var supportsUserCreation: Bool
	public var supportsUserUpdate: Bool
	public var supportsUserDeletion: Bool
	public var supportsPasswordChange: Bool
	
	public var wrappedUserToUserIdConversionStrategies: [WrappedUserToUserIdConversionStrategy]
	
	public init(
		globalConfig: GlobalConfig,
		providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?,
		url theURL: URL, secret s: Data,
		supportsUserCreation suc: Bool,
		supportsUserUpdate suu: Bool,
		supportsUserDeletion sud: Bool,
		supportsPasswordChange spc: Bool,
		wrappedUserToUserIdConversionStrategies wutuics: [WrappedUserToUserIdConversionStrategy]
	) {
		global = globalConfig
		
		precondition(id != "invalid" && id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		mergePriority = p
		
		url = theURL
		secret = s
		
		supportsUserCreation = suc
		supportsUserUpdate = suu
		supportsUserDeletion = sud
		supportsPasswordChange = spc
		
		wrappedUserToUserIdConversionStrategies = wutuics
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let url    = try genericConfig.url(forKey: "url",                     currentKeyPath: domain)
		let secret = try genericConfig.string(forKey: "secret",               currentKeyPath: domain)
		let suc    = try genericConfig.bool(forKey: "supportsUserCreation",   currentKeyPath: domain)
		let suu    = try genericConfig.bool(forKey: "supportsUserUpdate",     currentKeyPath: domain)
		let sud    = try genericConfig.bool(forKey: "supportsUserDeletion",   currentKeyPath: domain)
		let spc    = try genericConfig.bool(forKey: "supportsPasswordChange", currentKeyPath: domain)
		let p      = try genericConfig.optionalInt(forKey: "mergePriority",   currentKeyPath: domain)
		
		let wcs = try genericConfig.optionalArray(forKey: "wrappedUserToUserIdConversionStrategies", currentKeyPath: domain)
		let strategies = try wcs?.map{ try WrappedUserToUserIdConversionStrategy(genericStorage: $0, domainAliases: globalConfig.domainAliases, currentKeyPath: domain) }
		
		self.init(
			globalConfig: globalConfig,
			providerId: pId, serviceId: id, serviceName: name, mergePriority: p,
			url: url, secret: Data(secret.utf8),
			supportsUserCreation: suc,
			supportsUserUpdate: suu,
			supportsUserDeletion: sud,
			supportsPasswordChange: spc,
			wrappedUserToUserIdConversionStrategies: strategies ?? []
		)
	}
	
}
