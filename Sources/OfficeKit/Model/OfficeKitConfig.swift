/*
 * OfficeKitConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation



public struct OfficeKitConfig {
	
	public var authServiceId: String
	public var serviceConfigs: [String: AnyOfficeKitServiceConfig]
	
	/** Key is a domain alias, value is the actual domain */
	public var domainAliases: [String: String]
	
	/* ************
	   MARK: - Init
	   ************ */
	
	/** It is a programmer error to give an array of services containing two or
	more services with the same id. */
	public init(serviceConfigs s: [AnyOfficeKitServiceConfig], authServiceId asid: String, domainAliases da: [String: String]) throws {
		domainAliases = da
		authServiceId = asid
		serviceConfigs = [String: AnyOfficeKitServiceConfig](uniqueKeysWithValues: zip(s.map{ $0.serviceId }, s))
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
