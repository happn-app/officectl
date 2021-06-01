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
	
	struct TmpVaultAdditionalCertificate {
		let issuer: String
		let id: String
		init(string: String) throws {
			let components = string.split(separator: "/", omittingEmptySubsequences: false)
			guard components.count >= 2 else {
				throw InvalidArgumentError(message: "additional certificate should have format issuer/cert-id")
			}
			id = String(components.last!)
			issuer = components[components.startIndex..<components.index(before: components.endIndex)].joined(separator: "/")
		}
	}
	
	var tmpVaultBaseURL: URL?
	var tmpVaultIssuerName: String?
	/* Certificates will be revoked on the issuer name and the active issuers too */
	var tmpVaultAdditionalActiveIssuers: [String]?
	/* CA of the issuer name, the active issuers and the passive issuers will be
	 * included in the CA chain */
	var tmpVaultAdditionalPassiveIssuers: [String]?
	/* These additional certificates will be added in the CA chain. Format should
	 * be issuer/certificate_id */
	var tmpVaultAdditionalCertificates: [TmpVaultAdditionalCertificate]?
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
		
		let vaultConf = configYaml.storage(forKey: "vault_tmp")
		tmpVaultBaseURL = try vaultConf?.url(forKey: "base_url")
		tmpVaultToken = try vaultConf?.string(forKey: "token")
		tmpVaultTTL = try vaultConf?.string(forKey: "ttl")
		tmpVaultIssuerName = try vaultConf?.string(forKey: "issuer_name")
		tmpVaultAdditionalActiveIssuers = try vaultConf?.optionalArrayOfStrings(forKey: "additional_active_issuers")
		tmpVaultAdditionalPassiveIssuers = try vaultConf?.optionalArrayOfStrings(forKey: "additional_passive_issuers")
		tmpVaultAdditionalCertificates = try vaultConf?.optionalArrayOfStrings(forKey: "additional_certificate_ids")?.map{ try TmpVaultAdditionalCertificate(string: $0) }
		tmpVaultExpirationLeeway = try (vaultConf?.double(forKey: "max_expiration_delay_before_allowing_reissuance")).flatMap{ TimeInterval($0) }
		
		tmpSimpleMDMToken = try configYaml.storage(forKey: "simplemdm_tmp")?.string(forKey: "access_key")
		
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
