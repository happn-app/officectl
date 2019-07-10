/*
 * configure.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import OfficeKit
import Vapor
import Yaml



public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services, forcedConfigPath: String?) throws {
	let (url, conf) = try readYamlConfig(forcedConfigFilePath: forcedConfigPath)
	
	let serverConfigYaml = try conf.genericConfig(for: "server", domain: "Global config")
	let jwtSecret = try serverConfigYaml.string(for: "jwt_secret", domain: "Server Config")
	
	/* Register the Server config */
	do {
		let serverHostname = try serverConfigYaml.optionalString(for: "hostname", domain: "Server Config")
		let serverPort = try serverConfigYaml.optionalInt(for: "port", domain: "Server Config")
		switch (serverHostname, serverPort) {
		case (let hostname?, let port?): services.register(NIOServerConfig.default(hostname: hostname, port: port))
		case (let hostname?, nil):       services.register(NIOServerConfig.default(hostname: hostname))
		case (nil,           let port?): services.register(NIOServerConfig.default(                    port: port))
		case (nil,           nil):       (/*nop*/)
		}
	}
	
	/* Register the OpenDirectory config */
	do {
		let openDirectoryServiceConfigYaml = try conf.genericConfig(for: "open_directory_config", domain: "Global config")
		let openDirectoryServiceConfig = try OpenDirectoryServiceConfig(providerId: OpenDirectoryService.providerId, serviceId: "_internal_od_", serviceName: "Internal Open Directory Service", genericConfig: openDirectoryServiceConfigYaml, pathsRelativeTo: url)
		let openDirectoryService = OpenDirectoryService(config: openDirectoryServiceConfig)
		services.register(openDirectoryService)
	}
	
	/* Register the routes to the router */
	let router = EngineRouter.default()
	try setup_routes(router)
	services.register(router, as: Router.self)
	
	/* Register middleware */
	#warning("TODO: Request Signature validation middleware")
	var middlewares = MiddlewareConfig() /* Create _empty_ middleware config */
	middlewares.use(ErrorMiddleware.self) /* Catches errors and converts to HTTP response */
	services.register(middlewares)
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
			fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/officectl/opendirectory_officectlproxy.yaml", isDirectory: false),
			URL(fileURLWithPath: "/etc/officectl/opendirectory_officectlproxy.yaml", isDirectory: false)
		]
		guard let firstURL = searchedURLs.first(where: { fm.fileExists(atPath: $0.path, isDirectory: &isDir) && !isDir.boolValue }) else {
			throw MissingFieldError("Config file path")
		}
		configURL = firstURL
	}
	
	let configString = try String(contentsOf: configURL, encoding: .utf8)
	return try (configURL, Yaml.load(configString))
}
