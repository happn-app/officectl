/*
 * OfficectlConfig.swift
 * officectl
 *
 * Created by François Lamboley on 21/01/2019.
 */

import Foundation

import Guaka
import Vapor
import Yaml

import OfficeKit



struct OfficectlConfig : Service {
	
	var staticDataDirURL: URL?
	var serverHost: String
	var serverPort: Int
	
	var jwtSecret: String
	
	var verbose: Bool
	
	var tmpVaultBaseURL: URL?
	var tmpVaultIssuerName: String?
	var tmpVaultToken: String?
	var tmpVaultTTL: String?
	
	var officeKitConfig: OfficeKitConfig
	
	init(flags f: Flags) throws {
		let configYaml = try OfficectlConfig.readYamlConfig(forcedConfigFilePath: f.getString(name: "config-file"))
		
		staticDataDirURL = (f.getString(name: "static-data-dir") ?? configYaml["server"]["static_data_dir"].string).flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
		serverHost = f.getString(name: "hostname") ?? configYaml["server"]["hostname"].string ?? "localhost"
		serverPort = f.getInt(name: "port") ?? configYaml["server"]["port"].int ?? 8080
		
		guard let jSecret = f.getString(name: "jwt-secret") ?? configYaml["server"]["jwt_secret"].string else {
			throw MissingFieldError("JWT Secret")
		}
		jwtSecret = jSecret
		
		verbose = f.getBool(name: "verbose") ?? false
		
		tmpVaultBaseURL = configYaml["vault"]["base_url"].string.flatMap{ URL(string: $0) }
		tmpVaultIssuerName = configYaml["vault"]["issuer_name"].string
		tmpVaultToken = configYaml["vault"]["token"].string
		tmpVaultTTL = configYaml["vault"]["ttl"].string
		
		officeKitConfig = try OfficeKitConfig(genericConfig: configYaml)
	}
	
	private static func readYamlConfig(forcedConfigFilePath: String?) throws -> Yaml {
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
		return try Yaml.load(configString)
	}
	
}
