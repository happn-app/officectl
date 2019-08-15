/*
 * OfficeKitConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation

import GenericStorage
import Logging



public struct OfficeKitConfig {
	
	public static var logger: Logger?
	
	public var globalConfig: GlobalConfig
	
	public var authServiceConfig: AnyOfficeKitServiceConfig
	public var serviceConfigs: [String: AnyOfficeKitServiceConfig]
	
	public var orderedServiceConfigs: [AnyOfficeKitServiceConfig] {
		return serviceConfigs.values.sorted(by: { s1, s2 in
			switch (s1.mergePriority, s2.mergePriority) {
			case let (p1, p2) where p1 == p2: return s1.serviceId < s2.serviceId
				
			case let (.some(p1), .some(p2)): return p1 > p2
				
			case (.some, .none): return true
			case (.none, .some): return false
				
			default:
				OfficeKitConfig.logger?.warning("Internal logic error: Going in a case that shouldn’t be possible when sorting the service configs.")
				return true
			}
		})
	}
	
	/* ************
	   MARK: - Init
	   ************ */
	
	public init(genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = ["OfficeKit Config"]
		
		let gConfig = try GlobalConfig(genericConfig: genericConfig, pathsRelativeTo: baseURL)
		
		let authServiceId = try genericConfig.string(forKey: "auth_service_id", currentKeyPath: domain)
		let genericConfigServices = try genericConfig.dictionary(forKey: "services", currentKeyPath: domain)
		
		var serviceConfigsBuilding = [AnyOfficeKitServiceConfig]()
		for (serviceId, serviceInfo) in genericConfigServices {
			guard !serviceId.contains(":") else {
				throw InvalidArgumentError(message: "The id of a service cannot contain a colon.")
			}
			guard serviceId != "email" else {
				throw InvalidArgumentError(message: #"The id of a service cannot be equal to "email"."#)
			}
			guard serviceId != "invalid" else {
				throw InvalidArgumentError(message: #"The id of a service cannot be equal to "invalid"."#)
			}
			
			let keyPath = domain + ["services", serviceId]
			let serviceName = try serviceInfo.string(forKey: "name", currentKeyPath: keyPath)
			let provider = try serviceInfo.string(forKey: "provider", currentKeyPath: keyPath)
			let providerConfig = try serviceInfo.storage(forKey: "provider_config", currentKeyPath: keyPath)
			
			switch provider {
			case ExternalDirectoryServiceV1.providerId:
				let config = try ExternalDirectoryServiceV1Config(
					globalConfig: gConfig,
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(config.erased())
				
			case GitHubService.providerId:
				let config = try GitHubServiceConfig(
					globalConfig: gConfig,
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(config.erased())
				
			case GoogleService.providerId:
				let config = try GoogleServiceConfig(
					globalConfig: gConfig,
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(config.erased())
				
			case LDAPService.providerId:
				let config = try LDAPServiceConfig(
					globalConfig: gConfig,
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(config.erased())
				
			#if canImport(DirectoryService) && canImport(OpenDirectory)
			case OpenDirectoryService.providerId:
				let config = try OpenDirectoryServiceConfig(
					globalConfig: gConfig,
					providerId: provider,
					serviceId: serviceId,
					serviceName: serviceName,
					genericConfig: providerConfig,
					pathsRelativeTo: baseURL
				)
				serviceConfigsBuilding.append(config.erased())
			#endif
				
			default:
				throw InvalidArgumentError(message: "Unknown or unsupported service provider \(provider)")
			}
		}
		
		try self.init(globalConfig: gConfig, serviceConfigs: serviceConfigsBuilding, authServiceId: authServiceId)
	}
	
	/** It is a programmer error to give an array of services containing two or
	more services with the same id. */
	public init(globalConfig gConfig: GlobalConfig, serviceConfigs s: [AnyOfficeKitServiceConfig], authServiceId: String) throws {
		globalConfig = gConfig
		serviceConfigs = [String: AnyOfficeKitServiceConfig](uniqueKeysWithValues: zip(s.map{ $0.serviceId }, s))
		
		guard let c = serviceConfigs[authServiceId] else {
			throw InvalidArgumentError(message: "The auth service id does not correspond to a config")
		}
		authServiceConfig = c
	}
	
	public func getServiceConfig(id: String?) throws -> AnyOfficeKitServiceConfig {
		if let id = id {
			guard let config = serviceConfigs[id] else {
				throw InvalidArgumentError(message: "No service config with id \(id)")
			}
			return config
		} else {
			guard let config = serviceConfigs.values.first, serviceConfigs.count == 1 else {
				throw InvalidArgumentError(message: "Asked to retrieve a service config with no id specified, but there are no or more than one service configs in OfficeKit configs.")
			}
			return config
		}
	}
	
	public func getServiceConfig<ConfigType : OfficeKitServiceConfig>(id: String?) throws -> ConfigType {
		if let id = id {
			let untypedConfig = try getServiceConfig(id: id)
			guard let config: ConfigType = untypedConfig.unboxed() else {
				throw InvalidArgumentError(message: "Service config with id \(id) does not have expected type \(ConfigType.self).")
			}
			return config
		} else {
			let configs = serviceConfigs.values.compactMap{ $0.unboxed() as ConfigType? }
			guard let config = configs.first, configs.count == 1 else {
				throw InvalidArgumentError(message: "Asked to retrieve a service config of type \(ConfigType.self) with no id specified, but no or more service configs are present for this type.")
			}
			return config
		}
	}
	
}
