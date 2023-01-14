/*
 * configure.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation

import RetryingOperation
import SemiSingleton
import TOMLDecoder
import UnwrapOrThrow
import URLRequestOperation
import Vapor
import XDG

import OfficeKit
import OpenDirectoryOffice



func configure(_ app: Application, forcedConfigPath: String?, verbose: Bool) throws {
	SemiSingletonConfig.oslog = nil
	SemiSingletonConfig.logger = app.logger
	RetryingOperationConfig.oslog = nil
	RetryingOperationConfig.logger = app.logger
	URLRequestOperationConfig.oslog = nil
	URLRequestOperationConfig.logger = app.logger
	
	let dirs = try BaseDirectories(prefixAll: "officectl-odproxy", runtimeDirHandling: .skipSetup)
	let configPath = try forcedConfigPath ?? dirs.findConfigFile("config.toml")?.string ?! MessageError(message: "Cannot find file config file path.")
	let config = try TOMLDecoder().decode(AppConfig.self, from: Data(contentsOf: URL(fileURLWithPath: configPath)))
	
	/* Set hostname and port from server conf. */
	switch (config.serverConfig.hostname, config.serverConfig.port) {
		case (let hostname?, let port?): app.http.server.configuration.hostname = hostname; app.http.server.configuration.port = port
		case (let hostname?, nil):       app.http.server.configuration.hostname = hostname
		case (nil,           let port?): app.http.server.configuration.port = port
		case (nil,           nil):       (/*nop*/)
	}
	
	/* Setup the controllers and routes. */
	let odService = OpenDirectoryService(
		id: "_internal_od_",
		openDirectoryServiceConfig: OpenDirectoryServiceConfig(
			serviceName: "Open Directory Proxy for OfficeKit",
			connectorSettings: config.openDirectoryConfig,
			userIDBuilders: nil
		)
	)
	try configureRoutes(app, config.serverConfig, odService)
}
