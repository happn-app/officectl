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
	
	public func getAllServices() throws -> Set<AnyDirectoryService> {
		for (k, v) in officeKitConfig.serviceConfigs {
			guard servicesCache[k] == nil else {continue}
			servicesCache[k] = try directoryService(with: v)
		}
		return Set(servicesCache.values)
	}
	
	public func getDirectoryService(id: String?) throws -> AnyDirectoryService {
		let config = try officeKitConfig.getServiceConfig(id: id)
		return try directoryService(with: config)
	}
	
	public func getDirectoryService<DirectoryServiceType : DirectoryService>(id: String?) throws -> DirectoryServiceType {
		/* Special case: the erasure. If we try and get the erasure, we should
		 * call the specialized method instead.
		 * Another solution would be to specialize the unboxed() method of the
		 * erasure type to return the erasure if called with an erasure type, but
		 * it’s weird(er)… */
		guard DirectoryServiceType.self != AnyDirectoryService.self else {
			let s: AnyDirectoryService = try getDirectoryService(id: id)
			return s as! DirectoryServiceType
		}
		
		if let id = id {
			guard let directoryService: DirectoryServiceType = try getDirectoryService(id: id).unboxed() else {
				throw InvalidArgumentError(message: "Service with id \(id) does not have the correct type")
			}
			return directoryService
			
		} else {
			let configs = officeKitConfig.serviceConfigs.values.filter{ $0.providerId == DirectoryServiceType.providerId }
			guard let config = configs.onlyElement else {
				throw InvalidArgumentError(message: "No or too many directory services found for type \(DirectoryServiceType.providerId)")
			}
			return try directoryService(with: config).unboxed()!
		}
	}
	
	public func getDirectoryServices(ids: Set<String>?) throws -> Set<AnyDirectoryService> {
		guard let ids = ids else {return try getAllServices()}
		return try Set(ids.map{ try getDirectoryService(id: $0) })
	}
	
	public func getDirectoryAuthenticatorService() throws -> AnyDirectoryAuthenticatorService {
		return try directoryAuthenticatorService(with: officeKitConfig.authServiceConfig)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let officeKitConfig: OfficeKitConfig
	
	private var servicesCache = [String: AnyDirectoryService]()
	private var directoryAuthenticatorServiceCache: AnyDirectoryAuthenticatorService?
	
	private func directoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryService {
		if let service = servicesCache[config.serviceId] {
			return service
		}
		
		let service = try createDirectoryService(with: config)
		servicesCache[config.serviceId] = service
		return service
	}
	
	private func createDirectoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryService {
		guard let providerType = OfficeKitConfig.registeredServices[config.providerId] else {
			throw InvalidArgumentError(message: "Unregistered service provider \(config.providerId)")
		}
		
		guard let service = providerType.erasedService(anyConfig: config) else {
			throw InternalError(message: "Cannot init service with given config")
		}
		return service
	}
	
	private func directoryAuthenticatorService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryAuthenticatorService {
		if let authenticator = directoryAuthenticatorServiceCache {
			return authenticator
		}
		
		let authenticator = try createDirectoryAuthenticatorService(with: config)
		directoryAuthenticatorServiceCache = authenticator
		return authenticator
	}
	
	private func createDirectoryAuthenticatorService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryAuthenticatorService {
		switch config.providerId {
		case LDAPService.providerId:
			return LDAPService(config: config.unboxed()!).erased()
			
		default:
			throw InvalidArgumentError(message: "Unknown or unsupported service authenticator provider \(config.providerId)")
		}
	}
	
}
