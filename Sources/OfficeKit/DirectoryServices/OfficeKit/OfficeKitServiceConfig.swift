/*
 * OfficeKitConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation



public struct OfficeKitConfig {
	
	public var services: [String: OfficeKitService]
	/** Key is a domain alias, value is the actual domain */
	public var domainAliases: [String: String]
	
	/* ************
      MARK: - Init
	   ************ */
	
	/** It is a programmer error to give an array of services containing two or
	more services with the same id. */
	public init(domainAliases da: [String: String], services s: [OfficeKitService]) {
		domainAliases = da
		services = [String: OfficeKitService](uniqueKeysWithValues: zip(s.map{ $0.serviceId }, s))
	}
	
	public func getService<ServiceType : DirectoryService>(with id: String) -> ServiceType? {
		return services[id] as? ServiceType
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
