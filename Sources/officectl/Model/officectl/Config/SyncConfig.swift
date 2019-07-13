/*
 * SyncConfig.swift
 * officectl
 *
 * Created by François Lamboley on 12/07/2019.
 */

import Foundation

import OfficeKit



struct SyncConfig {
	
	var blacklistsByServiceId: [String: Set<String>]
	
	init(genericConfig conf: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "Sync Config"
		let blacklistConfig = try conf.stringGenericConfigDic(for: "blacklists_by_service", domain: domain)
		
		blacklistsByServiceId = try blacklistConfig.mapValues{ try Set($0.asStringArray(domain: domain)) }
	}
	
}
