/*
 * ServerConfig.swift
 * officectl
 *
 * Created by François Lamboley on 11/06/2020.
 */

import Foundation

import GenericStorage
import OfficeKit



struct ServerConfig {
	
	var serverHost: String
	var serverPort: Int
	
	var jwtSecret: Data
	
	init(serverOptions: ServerServeCommand.Options, genericConfig conf: GenericStorage?, pathsRelativeTo baseURL: URL?) throws {
		let domain = ["Server Config"]
		
		serverHost = (try? serverOptions.hostname ?? conf?.string(forKey: "hostname", currentKeyPath: domain)) ?? "localhost"
		serverPort = (try? serverOptions.port ?? conf?.int(forKey: "port", currentKeyPath: domain)) ?? 8080
		
		guard let s = try? conf?.string(forKey: "jwt_secret", currentKeyPath: domain) else {
			throw MissingFieldError("No JWT secret in server config")
		}
		jwtSecret = Data(s.utf8)
	}
	
}
