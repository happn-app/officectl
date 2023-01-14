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
import URLRequestOperation
import Vapor

import OfficeKit
import OpenDirectoryOffice



func configure(_ app: Application, forcedConfigPath: String?, verbose: Bool) throws {
	SemiSingletonConfig.oslog = nil
	SemiSingletonConfig.logger = app.logger
	RetryingOperationConfig.oslog = nil
	RetryingOperationConfig.logger = app.logger
	URLRequestOperationConfig.oslog = nil
	URLRequestOperationConfig.logger = app.logger
	
	let configURL = try configPath(withForcedPath: forcedConfigPath)
	let config = try TOMLDecoder().decode(AppConfig.self, from: Data(contentsOf: configURL))
	
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


private func configPath(withForcedPath forcedConfigFilePath: String?) throws -> URL {
	var isDir: ObjCBool = false
	let fm = FileManager.default
	if let path = forcedConfigFilePath {
		guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
			throw MessageError(message: "Cannot find file at path \(path).")
		}
		return URL(fileURLWithPath: path, isDirectory: false)
		
	} else {
		let searchedURLs = [
			fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/officectl/officectl-odproxy.yaml", isDirectory: false),
			URL(fileURLWithPath: "/etc/officectl/officectl-odproxy.yaml", isDirectory: false)
		]
		guard let firstURL = searchedURLs.first(where: { fm.fileExists(atPath: $0.path, isDirectory: &isDir) && !isDir.boolValue }) else {
			throw MessageError(message: "Cannot find config file.")
		}
		return firstURL
	}
}
