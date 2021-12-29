/*
 * configure.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation

import OfficeKit
import RetryingOperation
import SemiSingleton
import URLRequestOperation
import Vapor
import Yaml



func configure(_ app: Application, forcedConfigPath: String?, verbose: Bool) throws {
	SemiSingletonConfig.oslog = nil
	SemiSingletonConfig.logger = app.logger
	RetryingOperationConfig.oslog = nil
	RetryingOperationConfig.logger = app.logger
	URLRequestOperationConfig.oslog = nil
	URLRequestOperationConfig.logger = app.logger
	
	let (url, conf) = try readYamlConfig(forcedConfigFilePath: forcedConfigPath)
	let serverConfigYaml = try conf.storage(forKey: "server", currentKeyPath: ["Global config"])
	
	/* Register the global config */
	app.globalConfig = try GlobalConfig(genericConfig: conf, pathsRelativeTo: url)
	
	/* Register the Server config */
	do {
		let serverHostname = try serverConfigYaml.optionalString(forKey: "hostname", currentKeyPath: ["Server Config"])
		let serverPort = try serverConfigYaml.optionalInt(forKey: "port", currentKeyPath: ["Server Config"])
		switch (serverHostname, serverPort) {
			case (let hostname?, let port?): app.http.server.configuration.hostname = hostname; app.http.server.configuration.port = port
			case (let hostname?, nil):       app.http.server.configuration.hostname = hostname
			case (nil,           let port?): app.http.server.configuration.port = port
			case (nil,           nil):       (/*nop*/)
		}
	}
	
	/* Register the OpenDirectory config */
	let openDirectoryServiceConfigYaml = try conf.storage(forKey: "open_directory_config", currentKeyPath: ["Global config"])
	app.openDirectoryServiceConfig = try OpenDirectoryServiceConfig(providerId: OpenDirectoryService.providerId, serviceId: "_internal_od_", serviceName: "Internal Open Directory Service", mergePriority: nil, keyedConfig: openDirectoryServiceConfigYaml, pathsRelativeTo: url)
	
	try routes_and_middlewares(app, serverConfigYaml)
}


private func readYamlConfig(forcedConfigFilePath: String?) throws -> (URL, Yaml) {
	let configURL: URL
	var isDir: ObjCBool = false
	let fm = FileManager.default
	if let path = forcedConfigFilePath {
		guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
			throw InvalidArgumentError(message: "Cannot find file at path \(path)")
		}
		
		configURL = URL(fileURLWithPath: path, isDirectory: false)
	} else {
		let searchedURLs = [
			fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/officectl/officectl_odproxy.yaml", isDirectory: false),
			URL(fileURLWithPath: "/etc/officectl/officectl_odproxy.yaml", isDirectory: false)
		]
		guard let firstURL = searchedURLs.first(where: { fm.fileExists(atPath: $0.path, isDirectory: &isDir) && !isDir.boolValue }) else {
			throw MissingFieldError("Config file path")
		}
		configURL = firstURL
	}
	
	let configString = try String(contentsOf: configURL, encoding: .utf8)
	return try (configURL, Yaml.load(configString))
}
