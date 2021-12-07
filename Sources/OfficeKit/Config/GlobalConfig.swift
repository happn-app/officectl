/*
 * GlobalConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation

import GenericStorage



public struct GlobalConfig : Hashable {
	
	public var verbose = false
	
	/** Key is a domain alias, value is the actual domain */
	public var domainAliases = [String: String]()
	
	public init() {
	}
	
	public init(genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = ["OfficeKit Global Config"]
		verbose = try genericConfig.optionalBool(forKey: "verbose", currentKeyPath: domain) ?? false
		domainAliases = try genericConfig.optionalDictionaryOfStrings(forKey: "domain_aliases", currentKeyPath: domain) ?? [:]
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
