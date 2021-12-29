/*
 * SyncConfig.swift
 * officectl
 *
 * Created by François Lamboley on 12/07/2019.
 */

import Foundation

import GenericStorage
import OfficeKit



struct SyncConfig {
	
	var blacklistsByServiceId: [String: Set<String>]
	
	init(genericConfig conf: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = ["Sync Config"]
		let blacklistConfig = try conf.dictionary(forKey: "blacklists_by_service", currentKeyPath: domain)
		
		blacklistsByServiceId = try blacklistConfig.mapValues{ try Set($0.arrayOfStringsValue(currentKeyPath: domain)) }
	}
	
}
