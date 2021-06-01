/*
 * OfficectlConfig.swift
 * officectl
 *
 * Created by François Lamboley on 21/01/2019.
 */

import Foundation

import Yaml

import OfficeKit



struct OfficectlConfig {
	
	/** `env` is passed down to Vapor and shoud generally be ignored from there. */
	var env: String?
	var verbose: Bool
	var auditLogsURL: URL?
	
	var staticDataDirURL: URL?
	
	var serverConfig: ServerConfig?
	
	var tmpVaultBaseURL: URL?
	var tmpVaultRootCAName: String?
	var tmpVaultIssuerName: String?
	var tmpVaultAdditionalIssuers: [String]?
	var tmpVaultToken: String?
	var tmpVaultTTL: String?
	var tmpVaultExpirationLeeway: TimeInterval?
	
	var tmpSimpleMDMToken: String?
	
	var officeKitConfig: OfficeKitConfig
	var syncConfig: SyncConfig?
	
	init(globalOptions go: OfficectlRootCommand.Options, serverOptions so: ServerServeCommand.Options?) throws {
		let (configURL, configYaml) = try OfficectlConfig.readYamlConfig(forcedConfigFilePath: go.configFile)
		
		env = configYaml["env"].stringValue ?? go.env
		verbose = go.verbose ?? configYaml["verbose"].bool ?? false
		auditLogsURL = configYaml["audit_logs_path"].string.flatMap{ URL(fileURLWithPath: $0, isDirectory: false, relativeTo: configURL) }
		
		staticDataDirURL = (go.staticDataDir ?? configYaml["static_data_dir"].string).flatMap{ URL(fileURLWithPath: $0, isDirectory: true, relativeTo: configURL) }
		
		serverConfig = try so.flatMap{ try ServerConfig(serverOptions: $0, genericConfig: configYaml.optionalNonNullStorage(forKey: "server"), pathsRelativeTo: configURL) }
		
		tmpVaultBaseURL = configYaml["vault_tmp"]["base_url"].string.flatMap{ URL(string: $0) }
		tmpVaultRootCAName = configYaml["vault_tmp"]["root_ca_name"].string
		tmpVaultIssuerName = configYaml["vault_tmp"]["issuer_name"].string
		tmpVaultAdditionalIssuers = configYaml["vault_tmp"]["additional_issuers"].array?.compactMap{ $0.string }
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
