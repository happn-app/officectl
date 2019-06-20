/*
 * GitHubServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation


public struct GitHubConfig {
	
	public var connectorSettings: GitHubJWTConnector.Settings
	
	public init(connectorSettings c: GitHubJWTConnector.Settings) {
		connectorSettings = c
	}
	
}
