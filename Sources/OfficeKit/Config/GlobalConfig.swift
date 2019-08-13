/*
 * GlobalConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation



public struct GlobalConfig : Hashable {
	
	public var verbose = false
	
	/** Key is a domain alias, value is the actual domain */
	public var domainAliases = [String: String]()
	
	public init(genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "OfficeKit Global Config"
		verbose = try genericConfig.optionalBool(for: "verbose", domain: domain) ?? false
		domainAliases = try genericConfig.optionalStringStringDic(for: "domain_aliases", domain: domain) ?? [:]
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
