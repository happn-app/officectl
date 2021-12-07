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
	
	static public var logger: Logger?
	
	/* TODO: Allow clients of OfficeKit to register their own services! */
	static public private(set) var registeredServices: [String : OfficeKitServiceInit.Type] = {
		var res: [String : OfficeKitServiceInit.Type] = [
			EmailService.providerId:               EmailService.self,
			ExternalDirectoryServiceV1.providerId: ExternalDirectoryServiceV1.self,
			GitHubService.providerId:              GitHubService.self,
			GoogleService.providerId:              GoogleService.self,
			LDAPService.providerId:                LDAPService.self,
			HappnService.providerId:               HappnService.self
		]
#if canImport(DirectoryService) && canImport(OpenDirectory)
		res[OpenDirectoryService.providerId] = OpenDirectoryService.self
#endif
		return res
	}()
	
	public let globalConfig: GlobalConfig
	
	public let authServiceConfig: AnyOfficeKitServiceConfig
	public let serviceConfigs: [String: AnyOfficeKitServiceConfig]
	
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
			guard serviceId != "invalid" else {
				throw InvalidArgumentError(message: #"The id of a service cannot be equal to "invalid"."#)
			}
			
			let keyPath = domain + ["services", serviceId]
			let serviceName = try serviceInfo.string(forKey: "name", currentKeyPath: keyPath)
			let provider = try serviceInfo.string(forKey: "provider", currentKeyPath: keyPath)
			let priority = try serviceInfo.optionalInt(forKey: "merge_priority", errorOnMissingKey: false, currentKeyPath: keyPath)
			let providerConfig = try serviceInfo.storage(forKey: "provider_config", currentKeyPath: keyPath)
			
			guard let providerType = OfficeKitConfig.registeredServices[provider] else {
				throw InvalidArgumentError(message: "Unregistered service provider \(provider)")
			}
			let config = try providerType.configType.erasedConfig(
				providerId: provider,
				serviceId: serviceId,
				serviceName: serviceName,
				mergePriority: priority,
				keyedConfig: providerConfig,
				pathsRelativeTo: baseURL
			)
			serviceConfigsBuilding.append(config)
		}
		
		try self.init(globalConfig: gConfig, serviceConfigs: serviceConfigsBuilding, authServiceId: authServiceId)
	}
	
	/**
	 It is a programmer error to give an array of services containing two or more services with the same id. */
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
			guard let config = serviceConfigs.values.onlyElement else {
				throw InvalidArgumentError(message: "Asked to retrieve a service config with no id specified, but there are no or more than one service configs in OfficeKit configs.")
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
				throw InvalidArgumentError(message: "Service config with id \(id) does not have expected type \(ConfigType.self).")
			}
			return config
			
		} else {
			let configs = serviceConfigs.values.compactMap{ $0.unbox() as ConfigType? }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "Asked to retrieve a service config of type \(ConfigType.self) with no id specified, but no or more service configs are present for this type.")
			}
			return config
		}
	}
	
}
