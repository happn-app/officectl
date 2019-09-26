/*
 * OfficeKitServiceProvider.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import SemiSingleton



public class OfficeKitServiceProvider {
	
	public init(config cfg: OfficeKitConfig) {
		officeKitConfig = cfg
	}
	
	public func getAllServices() throws -> Set<AnyOfficeKitService> {
		for config in officeKitConfig.serviceConfigs.values {
			_ = try service(with: config)
		}
		return Set(servicesCache.values.filter{ !$0.config.isHelperService })
	}
	
	public func getService(id: String?) throws -> AnyOfficeKitService {
		let config = try officeKitConfig.getServiceConfig(id: id)
		return try service(with: config)
	}
	
	public func getService<ServiceType : OfficeKitService>(id: String?) throws -> ServiceType {
		/* Special case: the erasure. If we try and get the erasure, we should
		 * call the specialized method instead.
		 * Another solution would be to specialize the unboxed() method of the
		 * erasure type to return the erasure if called with an erasure type, but
		 * it’s weird(er)… */
		guard ServiceType.self != AnyOfficeKitService.self else {
			let s: AnyOfficeKitService = try getService(id: id)
			return s as! ServiceType
		}
		
		if let id = id {
			guard let service: ServiceType = try getService(id: id).unboxed() else {
				throw InvalidArgumentError(message: "Service with id \(id) does not have the correct type")
			}
			return service
			
		} else {
			let configs = officeKitConfig.serviceConfigs.values.filter{ $0.providerId == ServiceType.providerId }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "No or too many directory services found for type \(ServiceType.providerId)")
			}
			return try service(with: config).unboxed()!
		}
	}

	public func getServices(ids: Set<String>?) throws -> Set<AnyOfficeKitService> {
		guard let ids = ids else {return try getAllServices()}
		return try Set(ids.map{ try getService(id: $0) })
	}
	
	public func getAllUserDirectoryServices() throws -> Set<AnyUserDirectoryService> {
		for config in officeKitConfig.serviceConfigs.values where OfficeKitConfig.registeredServices[config.providerId] is UserDirectoryService.Type {
			_ = try userDirectoryService(with: config)
		}
		return Set(userDirectoryServicesCache.values.filter{ !$0.config.isHelperService })
	}
	
	/* *** TMP *** */
	public func getUserDirectoryService(id: String?) throws -> AnyUserDirectoryService {
		let config = try officeKitConfig.getServiceConfig(id: id)
		return try userDirectoryService(with: config)
	}
	
	/* *** TMP *** */
	public func getUserDirectoryServices(ids: Set<String>?) throws -> Set<AnyUserDirectoryService> {
		guard let ids = ids else {return try getAllUserDirectoryServices()}
		return try Set(ids.map{ try getUserDirectoryService(id: $0) })
	}
	
	/* *** TMP *** */
	public func getUserDirectoryService<ServiceType : UserDirectoryService>(id: String?) throws -> ServiceType {
		/* Special case: the erasure. If we try and get the erasure, we should
		 * call the specialized method instead.
		 * Another solution would be to specialize the unboxed() method of the
		 * erasure type to return the erasure if called with an erasure type, but
		 * it’s weird(er)… */
		guard ServiceType.self != AnyUserDirectoryService.self else {
			let s: AnyUserDirectoryService = try getUserDirectoryService(id: id)
			return s as! ServiceType
		}
		
		if let id = id {
			guard let service: ServiceType = try getUserDirectoryService(id: id).unboxed() else {
				throw InvalidArgumentError(message: "Service with id \(id) does not have the correct type")
			}
			return service
			
		} else {
			let configs = officeKitConfig.serviceConfigs.values.filter{ $0.providerId == ServiceType.providerId }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "No or too many directory services found for type \(ServiceType.providerId)")
			}
			return try userDirectoryService(with: config).unboxed()!
		}
	}
	
	/* *** TMP *** */
	public func getDirectoryAuthenticatorService() throws -> AnyDirectoryAuthenticatorService {
		return LDAPService(config: officeKitConfig.authServiceConfig.unboxed()!, globalConfig: officeKitConfig.globalConfig).erased()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let officeKitConfig: OfficeKitConfig
	
	private var servicesCache = [String: AnyOfficeKitService]()
	private var userDirectoryServicesCache = [String: AnyUserDirectoryService]()
	private var groupOfUsersDirectoryServicesCache = [String: AnyGroupOfUsersDirectoryService]()
	private var directoryAuthenticatorServiceCache: AnyDirectoryAuthenticatorService?
	
	private func service(with config: AnyOfficeKitServiceConfig) throws -> AnyOfficeKitService {
		if let service = servicesCache[config.serviceId] {
			return service
		}
		
		let service = try createService(with: config)
		servicesCache[config.serviceId] = service
		return service
	}
	
	private func createService(with config: AnyOfficeKitServiceConfig) throws -> AnyOfficeKitService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerId] else {
			throw InvalidArgumentError(message: "Unregistered service provider \(config.providerId)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config, globalConfig: officeKitConfig.globalConfig) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
	/* *** TMP *** */
	private func userDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyUserDirectoryService {
		if let service = userDirectoryServicesCache[config.serviceId] {
			return service
		}
		
		let service = try createDirectoryService(with: config)
		userDirectoryServicesCache[config.serviceId] = service
		return service
	}
	
	/* *** TMP *** */
	private func createDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyUserDirectoryService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerId] as? UserDirectoryServiceInit.Type else {
			throw InvalidArgumentError(message: "Unregistered or invalid type for service provider \(config.providerId)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config, globalConfig: officeKitConfig.globalConfig) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
}
