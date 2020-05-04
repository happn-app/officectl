/*
 * OfficectlConfig.swift
 * officectl
 *
 * Created by François Lamboley on 21/01/2019.
 */

import Foundation

import Guaka
import Yaml

import OfficeKit



struct OfficectlConfig {
	
	var staticDataDirURL: URL?
	var serverHost: String
	var serverPort: Int
	
	var jwtSecret: Data
	
	/** `env` is passed down to Vapor and shoud generally be ignored from there. */
	var env: String?
	var verbose: Bool
	var auditLogsURL: URL?
	
	var tmpVaultBaseURL: URL?
	var tmpVaultRootCAName: String?
	var tmpVaultIssuerName: String?
	var tmpVaultToken: String?
	var tmpVaultTTL: String?
	var tmpVaultExpirationLeeway: TimeInterval?
	
	var tmpSimpleMDMToken: String?
	
	var officeKitConfig: OfficeKitConfig
	var syncConfig: SyncConfig?
	
	init(flags f: Flags) throws {
		let (configURL, configYaml) = try OfficectlConfig.readYamlConfig(forcedConfigFilePath: f.getString(name: "config-file"))
		
		staticDataDirURL = (f.getString(name: "static-data-dir") ?? configYaml["server"]["static_data_dir"].string).flatMap{ URL(fileURLWithPath: $0, isDirectory: true, relativeTo: configURL) }
		serverHost = f.getString(name: "hostname") ?? configYaml["server"]["hostname"].string ?? "localhost"
		serverPort = f.getInt(name: "port") ?? configYaml["server"]["port"].int ?? 8080
		
		guard let jSecret = f.getString(name: "jwt-secret") ?? configYaml["server"]["jwt_secret"].string else {
			throw MissingFieldError("JWT Secret")
		}
		jwtSecret = Data(jSecret.utf8)
		
		env = configYaml["env"].stringValue
		verbose = f.getBool(name: "verbose") ?? configYaml["verbose"].bool ?? false
		auditLogsURL = configYaml["audit_logs_path"].string.flatMap{ URL(fileURLWithPath: $0, isDirectory: false, relativeTo: configURL) }
		
		tmpVaultBaseURL = configYaml["vault_tmp"]["base_url"].string.flatMap{ URL(string: $0) }
		tmpVaultRootCAName = configYaml["vault_tmp"]["root_ca_name"].string
		tmpVaultIssuerName = configYaml["vault_tmp"]["issuer_name"].string
		tmpVaultToken = configYaml["vault_tmp"]["token"].string
		tmpVaultTTL = configYaml["vault_tmp"]["ttl"].string
		tmpVaultExpirationLeeway = configYaml["vault_tmp"]["max_expiration_delay_before_allowing_reissuance"].int.flatMap{ TimeInterval($0) }
		
		tmpSimpleMDMToken = configYaml["simplemdm_tmp"]["access_key"].string
		
		officeKitConfig = try OfficeKitConfig(genericConfig: configYaml, pathsRelativeTo: configURL)
		syncConfig = try configYaml.optionalNonNullStorage(forKey: "sync").map{ try SyncConfig(genericConfig: $0, pathsRelativeTo: configURL) }
	}
	
	private static func readYamlConfig(forcedConfigFilePath: String?) throws -> (URL, Yaml) {
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
				URL(fileURLWithPath: "/etc/officectl/officectl.yaml", isDirectory: false),
				URL(fileURLWithPath: "/usr/local/etc/officectl/officectl.yaml", isDirectory: false)
			]
			guard let firstURL = searchedURLs.first(where: { fm.fileExists(atPath: $0.path, isDirectory: &isDir) && !isDir.boolValue }) else {
				throw MissingFieldError("Config file path")
			}
			configURL = firstURL
		}
		
		let configString = try String(contentsOf: configURL, encoding: .utf8)
		return try (configURL, Yaml.load(configString))
	}
	
}
