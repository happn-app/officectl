/*
 * OfficeKitServiceProvider.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/28.
 */

import Foundation

import SemiSingleton



public class OfficeKitServiceProvider {
	
	public init(config cfg: OfficeKitConfig) {
		officeKitConfig = cfg
	}
	
	/* ******************************************
	   MARK: Generic OfficeKit Services Retrieval
	   ****************************************** */
	
	public func getAllServices() throws -> Set<AnyOfficeKitService> {
		return try queue.sync{
			for config in officeKitConfig.serviceConfigs.values {
				_ = try service(with: config)
			}
			return Set(servicesCache.values.filter{ !$0.config.isHelperService })
		}
	}
	
	/* Convenience that avoids having to explicitly give the AnyOfficeKitService type to the compiler when using get Service for AnyOfficeKitService. */
	public func getService(id: String?) throws -> AnyOfficeKitService {
		let config = try officeKitConfig.getServiceConfig(id: id)
		return try queue.sync{ try service(with: config) }
	}
	
	public func getService<ServiceType : OfficeKitService>(id: String?) throws -> ServiceType {
		if let id = id {
			guard let service: ServiceType = try getService(id: id).unbox() else {
				throw InvalidArgumentError(message: "Service with ID \(id) does not have the correct type")
			}
			return service
			
		} else {
			let configs = officeKitConfig.serviceConfigs.values.filter{ $0.providerID == ServiceType.providerID }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "No or too many directory services found for type \(ServiceType.providerID)")
			}
			return try queue.sync{ try service(with: config) }.unbox()!
		}
	}
	
	public func getServices(ids: Set<String>?) throws -> Set<AnyOfficeKitService> {
		guard let ids = ids else {return try getAllServices()}
		/* Note: Not ideal, we lock the queue for each service ID (in the getService(id:) method)… */
		return try Set(ids.map{ try getService(id: $0) })
	}
	
	/* ***************************************
	   MARK: User Directory Services Retrieval
	   *************************************** */
	
	public func getAllUserDirectoryServices() throws -> Set<AnyUserDirectoryService> {
		return try queue.sync{
			for config in officeKitConfig.serviceConfigs.values where OfficeKitConfig.registeredServices[config.providerID] is UserDirectoryServiceInit.Type {
				_ = try userDirectoryService(with: config)
			}
			return Set(userDirectoryServicesCache.values.filter{ !$0.config.isHelperService })
		}
	}
	
	public func getUserDirectoryService(id: String?) throws -> AnyUserDirectoryService {
		let config = try officeKitConfig.getServiceConfig(id: id)
		return try queue.sync{ try userDirectoryService(with: config) }
	}
	
	public func getUserDirectoryService<ServiceType : UserDirectoryService>(id: String?) throws -> ServiceType {
		if let id = id {
			guard let service: ServiceType = try getUserDirectoryService(id: id).unbox() else {
				throw InvalidArgumentError(message: "Service with ID \(id) does not have the correct type")
			}
			return service
			
		} else {
			let configs = officeKitConfig.serviceConfigs.values.filter{ $0.providerID == ServiceType.providerID }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "No or too many directory services found for type \(ServiceType.providerID)")
			}
			return try queue.sync{ try userDirectoryService(with: config) }.unbox()!
		}
	}
	
	public func getUserDirectoryServices(ids: Set<String>?) throws -> Set<AnyUserDirectoryService> {
		guard let ids = ids else {return try getAllUserDirectoryServices()}
		return try Set(ids.map{ try getUserDirectoryService(id: $0) })
	}
	
	/* *************************************************
	   MARK: Group of Users Directory Services Retrieval
	   ************************************************* */
	
	public func getAllGroupOfUsersDirectoryServices() throws -> Set<AnyGroupOfUsersDirectoryService> {
		return try queue.sync{
			for config in officeKitConfig.serviceConfigs.values where OfficeKitConfig.registeredServices[config.providerID] is GroupOfUsersDirectoryServiceInit.Type {
				_ = try groupOfUsersDirectoryService(with: config)
			}
			return Set(groupOfUsersDirectoryServicesCache.values.filter{ !$0.config.isHelperService })
		}
	}
	
	public func getGroupOfUsersDirectoryService(id: String?) throws -> AnyGroupOfUsersDirectoryService {
		let config = try officeKitConfig.getServiceConfig(id: id)
		return try queue.sync{ try groupOfUsersDirectoryService(with: config) }
	}
	
	public func getGroupOfUsersDirectoryService<ServiceType : GroupOfUsersDirectoryService>(id: String?) throws -> ServiceType {
		if let id = id {
			guard let service: ServiceType = try getGroupOfUsersDirectoryService(id: id).unbox() else {
				throw InvalidArgumentError(message: "Service with ID \(id) does not have the correct type")
			}
			return service
			
		} else {
			let configs = officeKitConfig.serviceConfigs.values.filter{ $0.providerID == ServiceType.providerID }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "No or too many directory services found for type \(ServiceType.providerID)")
			}
			return try queue.sync{ try groupOfUsersDirectoryService(with: config) }.unbox()!
		}
	}
	
	public func getGroupOfUsersDirectoryServices(ids: Set<String>?) throws -> Set<AnyGroupOfUsersDirectoryService> {
		guard let ids = ids else {return try getAllGroupOfUsersDirectoryServices()}
		return try Set(ids.map{ try getGroupOfUsersDirectoryService(id: $0) })
	}
	
	/* ***********************************************
	   MARK: Directory Authenticator Service Retrieval
	   *********************************************** */
	
	public func getDirectoryAuthenticatorService() throws -> AnyDirectoryAuthenticatorService {
		return try queue.sync{ try directoryAuthenticatorService(with: officeKitConfig.authServiceConfig) }
	}
	
	public func getDirectoryAuthenticatorService<ServiceType : DirectoryAuthenticatorService>() throws -> ServiceType {
		guard let service: ServiceType = try getDirectoryAuthenticatorService().unbox() else {
			throw InvalidArgumentError(message: "Directory authenticator service does not have the correct type")
		}
		return service
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let officeKitConfig: OfficeKitConfig
	
	private let queue = DispatchQueue(label: "Service Provider Queue")
	
	private var servicesCache = [String: AnyOfficeKitService]()
	private var userDirectoryServicesCache = [String: AnyUserDirectoryService]()
	private var groupOfUsersDirectoryServicesCache = [String: AnyGroupOfUsersDirectoryService]()
	private var directoryAuthenticatorServiceCache: AnyDirectoryAuthenticatorService?
	
	/* ****************************************
	   MARK: Generic OfficeKit Service Creation
	   **************************************** */
	
	private func service(with config: AnyOfficeKitServiceConfig) throws -> AnyOfficeKitService {
		if let service = servicesCache[config.serviceID] {
			return service
		}
		
		let service = try createService(with: config)
		servicesCache[config.serviceID] = service
		return service
	}
	
	private func createService(with config: AnyOfficeKitServiceConfig) throws -> AnyOfficeKitService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerID] else {
			throw InvalidArgumentError(message: "Unregistered service provider \(config.providerID)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config, globalConfig: officeKitConfig.globalConfig, cachedServices: Array(servicesCache.values)) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
	/* *************************************
	   MARK: User Directory Service Creation
	   ************************************* */
	
	private func userDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyUserDirectoryService {
		if let service = userDirectoryServicesCache[config.serviceID] {
			return service
		}
		
		let service = try createUserDirectoryService(with: config)
		userDirectoryServicesCache[config.serviceID] = service
		servicesCache[config.serviceID] = service /* We might rewrite an already existing erasure in the cache, but it’s not a problem. */
		return service
	}
	
	private func createUserDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyUserDirectoryService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerID] as? UserDirectoryServiceInit.Type else {
			throw InvalidArgumentError(message: "Unregistered or invalid type for service provider \(config.providerID)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config, globalConfig: officeKitConfig.globalConfig, cachedServices: Array(servicesCache.values)) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
	/* ***********************************************
	   MARK: Group of Users Directory Service Creation
	   *********************************************** */
	
	private func groupOfUsersDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyGroupOfUsersDirectoryService {
		if let service = groupOfUsersDirectoryServicesCache[config.serviceID] {
			return service
		}
		
		let service = try createGroupOfUsersDirectoryService(with: config)
		groupOfUsersDirectoryServicesCache[config.serviceID] = service
		userDirectoryServicesCache[config.serviceID] = service
		servicesCache[config.serviceID] = service /* We might rewrite an already existing erasure in the cache, but it’s not a problem. */
		return service
	}
	
	private func createGroupOfUsersDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyGroupOfUsersDirectoryService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerID] as? GroupOfUsersDirectoryServiceInit.Type else {
			throw InvalidArgumentError(message: "Unregistered or invalid type for service provider \(config.providerID)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config, globalConfig: officeKitConfig.globalConfig, cachedServices: Array(servicesCache.values)) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
	/* **********************************************
	   MARK: Directory Authenticator Service Creation
	   ********************************************** */
	
	private func directoryAuthenticatorService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryAuthenticatorService {
		if let service = directoryAuthenticatorServiceCache {
			return service
		}
		
		let service = try createDirectoryAuthenticatorService(with: config)
		directoryAuthenticatorServiceCache = service
		userDirectoryServicesCache[config.serviceID] = service
		servicesCache[config.serviceID] = service /* We might rewrite an already existing erasure in the cache, but it’s not a problem. */
		return service
	}
	
	private func createDirectoryAuthenticatorService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryAuthenticatorService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerID] as? DirectoryAuthenticatorServiceInit.Type else {
			throw InvalidArgumentError(message: "Unregistered or invalid type for service provider \(config.providerID)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config, globalConfig: officeKitConfig.globalConfig, cachedServices: Array(servicesCache.values)) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
}
