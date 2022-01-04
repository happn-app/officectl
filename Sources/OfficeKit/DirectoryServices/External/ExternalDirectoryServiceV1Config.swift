/*
 * ExternalDirectoryServiceV1Config.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/09.
 */

import Foundation

import GenericStorage



public struct ExternalDirectoryServiceV1Config : OfficeKitServiceConfig {
	
	public var providerID: String
	public let isHelperService = false
	
	public var serviceID: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var url: URL
	public var secret: Data
	
	public var supportsUserCreation: Bool
	public var supportsUserUpdate: Bool
	public var supportsUserDeletion: Bool
	public var supportsPasswordChange: Bool
	
	public var wrappedUserToUserIDConversionStrategies: [WrappedUserToUserIDConversionStrategy]
	
	public init(
		providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?,
		url theURL: URL, secret s: Data,
		supportsUserCreation suc: Bool,
		supportsUserUpdate suu: Bool,
		supportsUserDeletion sud: Bool,
		supportsPasswordChange spc: Bool,
		wrappedUserToUserIDConversionStrategies wutuics: [WrappedUserToUserIDConversionStrategy]
	) {
		precondition(id != "invalid" && !id.contains(":"))
		providerID = pID
		serviceID = id
		serviceName = name
		mergePriority = p
		
		url = theURL
		secret = s
		
		supportsUserCreation = suc
		supportsUserUpdate = suu
		supportsUserDeletion = sud
		supportsPasswordChange = spc
		
		wrappedUserToUserIDConversionStrategies = wutuics
	}
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let url    = try keyedConfig.url(forKey: "url",                       currentKeyPath: domain)
		let secret = try keyedConfig.string(forKey: "secret",                 currentKeyPath: domain)
		let suc    = try keyedConfig.bool(forKey: "supports_user_creation",   currentKeyPath: domain)
		let suu    = try keyedConfig.bool(forKey: "supports_user_update",     currentKeyPath: domain)
		let sud    = try keyedConfig.bool(forKey: "supports_user_deletion",   currentKeyPath: domain)
		let spc    = try keyedConfig.bool(forKey: "supports_password_change", currentKeyPath: domain)
		
		let wcs = try keyedConfig.optionalArray(forKey: "wrapped_user_to_user_id_conversion_strategies", currentKeyPath: domain)
		let strategies = try wcs?.map{ try WrappedUserToUserIDConversionStrategy(genericStorage: $0, currentKeyPath: domain) }
		
		self.init(
			providerID: pID, serviceID: id, serviceName: name, mergePriority: p,
			url: url, secret: Data(secret.utf8),
			supportsUserCreation: suc,
			supportsUserUpdate: suu,
			supportsUserDeletion: sud,
			supportsPasswordChange: spc,
			wrappedUserToUserIDConversionStrategies: strategies ?? []
		)
	}
	
}
