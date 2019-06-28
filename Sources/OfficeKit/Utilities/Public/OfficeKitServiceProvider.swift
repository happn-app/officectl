/*
 * OfficeKitServiceProvider.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import SemiSingleton
import Vapor



public class OfficeKitServiceProvider {
	
	init(officeKitConfig cfg: OfficeKitConfig, container c: Container) {
		officeKitConfig = cfg
		container = c
	}
	
	public func getAllServices() throws -> [AnyDirectoryService] {
		for (k, v) in officeKitConfig.serviceConfigs {
			guard servicesCache[k] == nil else {continue}
			servicesCache[k] = try directoryService(with: v)
		}
		return Array(servicesCache.values)
	}
	
	public func getDirectoryService(with id: String) throws -> AnyDirectoryService {
		guard let config = officeKitConfig.serviceConfigs[id] else {
			throw InvalidArgumentError(message: "No service configured with id \(id)")
		}
		return try directoryService(with: config)
	}
	
	public func getDirectoryAuthenticatorService() throws -> AnyDirectoryAuthenticatorService {
		return try directoryAuthenticatorService(with: officeKitConfig.authServiceConfig)
	}
	
	public func directoryService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryService {
		let ac = try container.make(AsyncConfig.self)
		let sms = try container.make(SemiSingletonStore.self)
		
		if let cfg: GitHubServiceConfig = config.unwrapped() {
			return try AnyDirectoryService(
				GitHubService(config: cfg, semiSingletonStore: sms, asyncConfig: ac),
				asyncConfig: ac
			)
		}
		
		if let cfg: GoogleServiceConfig = config.unwrapped() {
			return try AnyDirectoryService(
				GoogleService(config: cfg, semiSingletonStore: sms, asyncConfig: ac),
				asyncConfig: ac
			)
		}
		
		if let cfg: LDAPServiceConfig = config.unwrapped() {
			return try AnyDirectoryService(
				LDAPService(ldapConfig: cfg, domainAliases: officeKitConfig.domainAliases, semiSingletonStore: sms, asyncConfig: ac),
				asyncConfig: ac
			)
		}
		
		#if canImport(DirectoryService) && canImport(OpenDirectory)
		if let cfg: OpenDirectoryServiceConfig = config.unwrapped() {
			return try AnyDirectoryService(
				OpenDirectoryService(config: cfg, semiSingletonStore: sms, asyncConfig: ac),
				asyncConfig: ac
			)
		}
		#endif
		
		throw InvalidArgumentError(message: "Unknown directory service config type")
	}
	
	public func directoryAuthenticatorService(with config: AnyOfficeKitServiceConfig) throws -> AnyDirectoryAuthenticatorService {
		let ac = try container.make(AsyncConfig.self)
		let sms = try container.make(SemiSingletonStore.self)
		
		if let cfg: LDAPServiceConfig = config.unwrapped() {
			return try AnyDirectoryAuthenticatorService(
				LDAPService(ldapConfig: cfg, domainAliases: officeKitConfig.domainAliases, semiSingletonStore: sms, asyncConfig: ac),
				asyncConfig: ac
			)
		}
		
		throw InvalidArgumentError(message: "Unknown directory service config type")
	}
	
	private let container: Container
	private let officeKitConfig: OfficeKitConfig
	
	private var servicesCache = [String: AnyDirectoryService]()
	
}
