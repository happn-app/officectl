/*
 * configure.swift
 * officectl
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import OfficeKit
import Vapor
import Yaml



public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services, forcedConfigPath: String?) throws {
	let conf = try readYamlConfig(forcedConfigFilePath: forcedConfigPath)
	
	/* Register routes to the router */
	let router = EngineRouter.default()
	try routes(router)
	services.register(router, as: Router.self)
	
	/* Register middleware */
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
			fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/officectl/officectl.yaml", isDirectory: false),
			URL(fileURLWithPath: "/etc/officectl/officectl.yaml", isDirectory: false)
		]
		guard let firstURL = searchedURLs.first(where: { fm.fileExists(atPath: $0.path, isDirectory: &isDir) && !isDir.boolValue }) else {
			throw MissingFieldError("Config file path")
		}
		configURL = firstURL
	}
	
	let configString = try String(contentsOf: configURL, encoding: .utf8)
	return try (configURL, Yaml.load(configString))
}
