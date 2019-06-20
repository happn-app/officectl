/*
 * GoogleServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct GoogleServiceConfig {
	
	public var connectorSettings: GoogleJWTConnector.Settings
	public var primaryDomains: Set<String>
	
	public init(connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: Set<String>) {
		connectorSettings = c
		primaryDomains = d
	}
	
}
