/*
 * configure.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import OfficeKit
import SemiSingleton
import Vapor
import Yaml



public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services, forcedConfigPath: String?, verbose: Bool) throws {
	configureURLRequestOperation(verbose)
	configureRetryingOperation(verbose)
	configureSemiSingleton(verbose)
	
	let (url, conf) = try readYamlConfig(forcedConfigFilePath: forcedConfigPath)
	
	let serverConfigYaml = try conf.genericConfig(for: "server", domain: "Global config")
	let secret = try serverConfigYaml.string(for: "secret", domain: "Server Config")
	
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
	
	/* Register additional services */
	services.register(SemiSingletonStore(forceClassInKeys: true))
	
	/* Register the routes to the router */
	let router = EngineRouter.default()
	try setup_routes(router)
	services.register(router, as: Router.self)
	
	/* Register middleware */
	#warning("TODO: Request Signature validation middleware")
	var middlewares = MiddlewareConfig() /* Create _empty_ middleware config */
	middlewares.use(ErrorMiddleware(handleError)) /* Catches errors and converts to HTTP response */
	middlewares.use(VerifySignatureMiddleware(secret: Data(secret.utf8)))
	services.register(middlewares)
}


private func handleError(req: Request, error: Error) -> Response {
	do {
		#warning("TODO: Log the error")
		return try ApiResponse<String>(error: error).syncEncode(for: req)
	} catch {
		return req.response(#"{"error":{"domain":"top","code":42,"message":"Cannot even encode the upstream error…"}}"#, as: .json)
	}
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
