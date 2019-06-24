/*
 * OfficeKitConfigurableService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Vapor



//public protocol OfficeKitServiceConfig {
//	
//	init(dictionary: [String: Any?]) throws
//	
//}
//
//extension OfficeKitServiceConfig {
//	
//	/* Internal convenience for OfficeKit service configs to implement the init. */
//	static func getConfigValue<T>(from dictionary: [String: Any?], key: String, domain: String) throws -> T {
//		guard let v = dictionary[key] as? T else {throw InvalidConfigError(configDomain: domain, configKey: key)}
//		return v
//	}
//	
//}
//
//
//public protocol OfficeKitConfigurableService : OfficeKitService {
//	
//	associatedtype ConfigType : OfficeKitServiceConfig
//	
//	var serviceConfig: ConfigType {get}
//	
//	init(serviceId: String, serviceName: String, serviceConfig: ConfigType, container: Container)
//	
//}
//
//public extension OfficeKitConfigurableService {
//	
//	init(serviceId: String, serviceName: String, serviceConfigDictionary: [String: Any?], container: Container) throws {
//		let config = try ConfigType.init(dictionary: serviceConfigDictionary)
//		self.init(serviceId: serviceId, serviceName: serviceName, serviceConfig: config, container: container)
//	}
//	
//}
