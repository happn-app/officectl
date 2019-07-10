/*
 * ExternalDirectoryServiceV1Config.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation



public struct ExternalDirectoryServiceV1Config : OfficeKitServiceConfig {
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var url: URL
	public var jwtSecret: Data
	
	public var supportedServiceIdsForLogicalUserConversion: Set<String>?
	public var supportsUserCreation: Bool
	public var supportsUserUpdate: Bool
	public var supportsUserDeletion: Bool
	public var supportsPasswordChange: Bool
	
	public init(
		providerId pId: String, serviceId id: String, serviceName name: String,
		url theURL: URL, jwtSecret secret: Data,
		supportedServiceIdsForLogicalUserConversion sids: Set<String>?,
		supportsUserCreation suc: Bool,
		supportsUserUpdate suu: Bool,
		supportsUserDeletion sud: Bool,
		supportsPasswordChange spc: Bool
	) {
		precondition(id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		url = theURL
		jwtSecret = secret
		
		supportedServiceIdsForLogicalUserConversion = sids
		supportsUserCreation = suc
		supportsUserUpdate = suu
		supportsUserDeletion = sud
		supportsPasswordChange = spc
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "External Directory Service V1"
		let url       = try genericConfig.url(for: "url",                                                               domain: domain)
		let jwtSecret = try genericConfig.string(for: "jwt_secret",                                                     domain: domain)
		let sids      = try genericConfig.optionalStringArray(for: "supported_service_ids_for_logical_user_conversion", domain: domain)
		let suc       = try genericConfig.optionalBool(for: "supportsUserCreation",                                     domain: domain) ?? true
		let suu       = try genericConfig.optionalBool(for: "supportsUserUpdate",                                       domain: domain) ?? true
		let sud       = try genericConfig.optionalBool(for: "supportsUserDeletion",                                     domain: domain) ?? true
		let spc       = try genericConfig.optionalBool(for: "supportsPasswordChange",                                   domain: domain) ?? true
		
		self.init(
			providerId: pId, serviceId: id, serviceName: name,
			url: url, jwtSecret: Data(jwtSecret.utf8),
			supportedServiceIdsForLogicalUserConversion: sids.map{ Set($0) },
			supportsUserCreation: suc,
			supportsUserUpdate: suu,
			supportsUserDeletion: sud,
			supportsPasswordChange: spc
		)
	}
	
	public func supportsServiceIdForLogicalUserConversion(_ serviceId: String) -> Bool {
		guard let l = supportedServiceIdsForLogicalUserConversion else {return true}
		return l.contains(serviceId)
	}
	
}
