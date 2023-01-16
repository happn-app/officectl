/*
 * OfficeKitConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/01/11.
 */

import Foundation

import GenericStorage
import Logging



public struct OfficeKitConfig {
	
	static public var logger: Logger?
	
	/* TODO: Allow clients of OfficeKit to register their own services! */
	static public private(set) var registeredServices: [String: OfficeKitServiceInit.Type] = {
		var res: [String: OfficeKitServiceInit.Type] = [
			EmailService.providerID:               EmailService.self,
			ExternalDirectoryServiceV1.providerID: ExternalDirectoryServiceV1.self,
			GitHubService.providerID:              GitHubService.self,
			GoogleService.providerID:              GoogleService.self,
			LDAPService.providerID:                LDAPService.self,
			HappnService.providerID:               HappnService.self
		]
#if canImport(DirectoryService) && canImport(OpenDirectory)
		res[OpenDirectoryService.providerID] = OpenDirectoryService.self
#endif
		return res
	}()
	
	public let globalConfig: GlobalConfig
	
	public let authServiceConfig: any OfficeKitServiceConfig
	public let serviceConfigs: [String: any OfficeKitServiceConfig]
	
	public var orderedServiceConfigs: [any OfficeKitServiceConfig] {
		return serviceConfigs.values.sorted(by: { s1, s2 in
			switch (s1.mergePriority, s2.mergePriority) {
				case let (p1, p2) where p1 == p2: return s1.serviceID < s2.serviceID
					
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
		
		let authServiceID = try genericConfig.string(forKey: "auth_service_id", currentKeyPath: domain)
		let genericConfigServices = try genericConfig.dictionary(forKey: "services", currentKeyPath: domain)
		
		var serviceConfigsBuilding = [AnyOfficeKitServiceConfig]()
		for (serviceID, serviceInfo) in genericConfigServices {
			guard !serviceID.contains(":") else {
				throw InvalidArgumentError(message: "The ID of a service cannot contain a colon.")
			}
			guard serviceID != "invalid" else {
				throw InvalidArgumentError(message: #"The ID of a service cannot be equal to "invalid"."#)
			}
			
			let keyPath = domain + ["services", serviceID]
			let serviceName = try serviceInfo.string(forKey: "name", currentKeyPath: keyPath)
			let provider = try serviceInfo.string(forKey: "provider", currentKeyPath: keyPath)
			let priority = try serviceInfo.optionalInt(forKey: "merge_priority", errorOnMissingKey: false, currentKeyPath: keyPath)
			let providerConfig = try serviceInfo.storage(forKey: "provider_config", currentKeyPath: keyPath)
			
			guard let providerType = OfficeKitConfig.registeredServices[provider] else {
				throw InvalidArgumentError(message: "Unregistered service provider \(provider)")
			}
			let config = try providerType.configType.erasedConfig(
				providerID: provider,
				serviceID: serviceID,
				serviceName: serviceName,
				mergePriority: priority,
				keyedConfig: providerConfig,
				pathsRelativeTo: baseURL
			)
			serviceConfigsBuilding.append(config)
		}
		
		try self.init(globalConfig: gConfig, serviceConfigs: serviceConfigsBuilding, authServiceID: authServiceID)
	}
	
	/**
	 It is a programmer error to give an array of services containing two or more services with the same id. */
	public init(globalConfig gConfig: GlobalConfig, serviceConfigs s: [any OfficeKitServiceConfig], authServiceID: String) throws {
		globalConfig = gConfig
		serviceConfigs = [String: any OfficeKitServiceConfig](uniqueKeysWithValues: zip(s.map{ $0.serviceID }, s))
		
		guard let c = serviceConfigs[authServiceID] else {
			throw InvalidArgumentError(message: "The auth service ID does not correspond to a config")
		}
		authServiceConfig = c
	}
	
	public func getServiceConfig(id: String?) throws -> any OfficeKitServiceConfig {
		if let id = id {
			guard let config = serviceConfigs[id] else {
				throw InvalidArgumentError(message: "No service config with ID \(id)")
			}
			return config
			
		} else {
			guard let config = serviceConfigs.values.onlyElement else {
				throw InvalidArgumentError(message: "Asked to retrieve a service config with no ID specified, but there are no or more than one service configs in OfficeKit configs.")
			}
			return config
		}
	}
	
	public func getServiceConfig<ConfigType : OfficeKitServiceConfig>(id: String?) throws -> ConfigType {
		/* See service provider for explanation of this guard. */
		guard ConfigType.self != AnyOfficeKitServiceConfig.self else {
			let c: AnyOfficeKitServiceConfig = try getServiceConfig(id: id)
			return c as! ConfigType
		}
		
		if let id = id {
			let untypedConfig = try getServiceConfig(id: id)
			guard let config: ConfigType = untypedConfig.unbox() else {
				throw InvalidArgumentError(message: "Service config with ID \(id) does not have expected type \(ConfigType.self).")
			}
			return config
			
		} else {
			let configs = serviceConfigs.values.compactMap{ $0.unbox() as ConfigType? }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "Asked to retrieve a service config of type \(ConfigType.self) with no ID specified, but no or more service configs are present for this type.")
			}
			return config
		}
	}
	
}