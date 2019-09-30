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



struct ConfigureOptions {
	
	var verbose: Bool
	
	var serverSecret: String
	var globalConf: GlobalConfig
	
	let signatureURLPathPrefixTransform: VerifySignatureMiddleware.SignatureURLPathPrefixTransform?
	
	let serverHostname: String?
	let serverPort: Int?
	
	let openDirectoryConfig: OpenDirectoryServiceConfig
	
}


func prepareConfigure(forcedConfigPath: String?, verbose: Bool) throws -> ConfigureOptions {
	let (url, conf) = try readYamlConfig(forcedConfigFilePath: forcedConfigPath)
	
	let serverConfigYaml = try conf.storage(forKey: "server", currentKeyPath: ["Global config"])
	let secret = try serverConfigYaml.string(forKey: "secret", currentKeyPath: ["Server Config"])
	let globalConf = try GlobalConfig(genericConfig: conf, pathsRelativeTo: url)
	
	let signatureURLPathPrefixTransform: VerifySignatureMiddleware.SignatureURLPathPrefixTransform?
	if let transformObject = try serverConfigYaml.optionalNonNullStorage(forKey: "signature_url_path_prefix_transform", currentKeyPath: ["Server Config"]) {
		signatureURLPathPrefixTransform = (
			from: try transformObject.string(forKey: "from", currentKeyPath: ["Signature URL Prefix Transform"]),
			to:   try transformObject.string(forKey: "to",   currentKeyPath: ["Signature URL Prefix Transform"])
		)
	} else {
		signatureURLPathPrefixTransform = nil
	}
	
	let serverHostname = try serverConfigYaml.optionalString(forKey: "hostname", currentKeyPath: ["Server Config"])
	let serverPort = try serverConfigYaml.optionalInt(forKey: "port", currentKeyPath: ["Server Config"])
	
	let openDirectoryServiceConfigYaml = try conf.storage(forKey: "open_directory_config", currentKeyPath: ["Global config"])
	let openDirectoryServiceConfig = try OpenDirectoryServiceConfig(providerId: OpenDirectoryService.providerId, serviceId: "_internal_od_", serviceName: "Internal Open Directory Service", mergePriority: nil, keyedConfig: openDirectoryServiceConfigYaml, pathsRelativeTo: url)
	
	return ConfigureOptions(
		verbose: verbose,
		serverSecret: secret,
		globalConf: globalConf,
		signatureURLPathPrefixTransform: signatureURLPathPrefixTransform,
		serverHostname: serverHostname,
		serverPort: serverPort,
		openDirectoryConfig: openDirectoryServiceConfig
	)
}


func configureServices(_ services: inout Services, configureOptions: ConfigureOptions) {
	configureURLRequestOperation(configureOptions.verbose)
	configureRetryingOperation(configureOptions.verbose)
	configureSemiSingleton(configureOptions.verbose)
	
	/* Register the Server config */
	switch (configureOptions.serverHostname, configureOptions.serverPort) {
	case (let hostname?, let port?): services.register(HTTPServer.Configuration.self, { c in .init(hostname: hostname, port: port) })
	case (let hostname?, nil):       services.register(HTTPServer.Configuration.self, { c in .init(hostname: hostname)             })
	case (nil,           let port?): services.register(HTTPServer.Configuration.self, { c in .init(                    port: port) })
	case (nil,           nil):       (/*nop*/)
	}
	
	/* Register the OpenDirectory config */
	services.register(OpenDirectoryService.self, { c in
		return OpenDirectoryService(config: configureOptions.openDirectoryConfig, globalConfig: configureOptions.globalConf)
	})
	
	/* Register additional services */
	services.register(SemiSingletonStore.self, { c in SemiSingletonStore(forceClassInKeys: true) })
	
	/* Register the routes to the router */
	services.extend(Routes.self, routes)
	
	/* Register middleware */
	services.register(MiddlewareConfiguration.self, { c in
		 var middlewares = MiddlewareConfiguration() /* Create _empty_ middleware config */
		 middlewares.use(ErrorMiddleware(handleError)) /* Catches errors and converts to HTTP response */
		 middlewares.use(VerifySignatureMiddleware(secret: Data(configureOptions.serverSecret.utf8), signatureURLPathPrefixTransform: configureOptions.signatureURLPathPrefixTransform))
		 return middlewares
	})
}


private func handleError(req: Request, error: Error) -> Response {
	do {
		#warning("TODO: Log the error")
		return try ApiResponse<String>(error: error).syncEncode(for: req)
	} catch {
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .contentType, value: "application/json")
		return Response(status: .internalServerError, headers: headers, body: Response.Body(string: #"{"error":{"domain":"top","code":42,"message":"Cannot even encode the upstream error…"}}"#))
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
