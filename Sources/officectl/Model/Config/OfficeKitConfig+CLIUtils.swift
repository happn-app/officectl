/*
 * OfficeKitConfig+CLIUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation

import Guaka
import Vapor
import Yaml

import OfficeKit



extension OfficeKitConfig : Service {
	
	init(flags f: Flags, yamlConfig: Yaml) throws {
		let domainAliases = try yamlConfig.optionalStringStringDic(for: "domain_aliases") ?? [:]
		
		let authServiceId = try yamlConfig.string(for: "auth_service_id")
		let yamlServices = try yamlConfig.stringYamlDic(for: "services")
		
		var services = [OfficeKitService]()
		for (serviceId, serviceInfo) in yamlServices {
			let serviceName = try serviceInfo.string(for: "name")
			let provider = try serviceInfo.string(for: "provider")
			let providerConfig = try serviceInfo.stringYamlDic(for: "provider_config")
			
			switch provider {
			case "internal_openldap":
				()
				
			case "internal_google":
				()
				
			case "internal_github":
				()
				
			case "internal_opendirectory":
				#if canImport(DirectoryService) && canImport(OpenDirectory)
				()
				#else
				fallthrough
				#endif
				
			case "internal_happn":
				fallthrough

			case "internal_vault":
				fallthrough
				
			case "http_service_v1":
				fallthrough
				
			default:
				throw InvalidArgumentError(message: "Unknown or unsupported service provider \(provider)")
			}
		}
		
		try self.init(services: services, authServiceId: authServiceId, domainAliases: domainAliases)
	}
	
}
