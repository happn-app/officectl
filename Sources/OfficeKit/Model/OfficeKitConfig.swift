/*
 * OfficeKitConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation



public struct OfficeKitConfig {
	
	public var authServiceConfig: AnyOfficeKitServiceConfig
	public var serviceConfigs: [String: AnyOfficeKitServiceConfig]
	
	/** Key is a domain alias, value is the actual domain */
	public var domainAliases: [String: String]
	
	/* ************
	   MARK: - Init
	   ************ */
	
	public init(genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "OfficeKit Config"
		let domainAliases = try genericConfig.optionalStringStringDic(for: "domain_aliases", domain: domain) ?? [:]
		
		let authServiceId = try genericConfig.string(for: "auth_service_id", domain: domain)
		let genericConfigServices = try genericConfig.stringGenericConfigDic(for: "services", domain: domain)
		
		var serviceConfigsBuilding = [AnyOfficeKitServiceConfig]()
		for (serviceId, serviceInfo) in genericConfigServices {
			let domain = "Service \(serviceId)"
			let serviceName = try serviceInfo.string(for: "name", domain: domain)
			let provider = try serviceInfo.string(for: "provider", domain: domain)
			let providerConfig = try serviceInfo.genericConfig(for: "provider_config", domain: domain)
			
			switch provider {
			case LDAPService.providerId:
				let config = try LDAPServiceConfig(
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(AnyOfficeKitServiceConfig(config))
				
			case GoogleService.providerId:
				let config = try GoogleServiceConfig(
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(AnyOfficeKitServiceConfig(config))
				
			case GitHubService.providerId:
				let config = try GitHubServiceConfig(
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(AnyOfficeKitServiceConfig(config))
				
			#if canImport(DirectoryService) && canImport(OpenDirectory)
			case OpenDirectoryService.providerId:
				let config = try OpenDirectoryServiceConfig(
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(AnyOfficeKitServiceConfig(config))
			#endif
				
			default:
				throw InvalidArgumentError(message: "Unknown or unsupported service provider \(provider)")
			}
		}
		
		try self.init(serviceConfigs: serviceConfigsBuilding, authServiceId: authServiceId, domainAliases: domainAliases)
	}
	
	/** It is a programmer error to give an array of services containing two or
	more services with the same id. */
	public init(serviceConfigs s: [AnyOfficeKitServiceConfig], authServiceId: String, domainAliases da: [String: String]) throws {
		domainAliases = da
		serviceConfigs = [String: AnyOfficeKitServiceConfig](uniqueKeysWithValues: zip(s.map{ $0.serviceId }, s))
		
		guard let c = serviceConfigs[authServiceId] else {
			throw InvalidArgumentError(message: "The auth service id does not correspond to a config")
		}
		authServiceConfig = c
	}
	
	public func mainDomain(for domain: String) -> String {
		if let d = domainAliases[domain] {return d}
		return domain
	}
	
	public func equivalentDomains(for domain: String) -> Set<String> {
		let base = mainDomain(for: domain)
		return domainAliases.reduce([base], { currentResult, keyval in
			if keyval.value == base {return currentResult.union([keyval.key])}
			return currentResult
		})
	}
	
}
