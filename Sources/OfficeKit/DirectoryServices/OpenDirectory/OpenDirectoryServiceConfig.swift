/*
 * OpenDirectoryServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation



public struct OpenDirectoryServiceConfig {
	
	public var connectorSettings: OpenDirectoryConnector.Settings
	public var authenticatorSettings: OpenDirectoryRecordAuthenticator.Settings
	
	public init(connectorSettings c: OpenDirectoryConnector.Settings, authenticatorSettings a: OpenDirectoryRecordAuthenticator.Settings) {
		connectorSettings = c
		authenticatorSettings = a
	}
	
}

#endif
