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
		
		officeKitConfig = try OfficeKitConfig(flags: f, yamlConfig: configYaml)
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



/* Conveniences for retrieving some options */
extension OfficectlConfig {
	
	static func stringArrayFrom(yamlConfig: [Yaml: Yaml], yamlName: String) throws -> [String] {
		guard let confArray = yamlConfig[Yaml.string(yamlName)]?.array else {
			throw InvalidArgumentError(message: "The conf file has an invalid value (not an array) for key \(yamlName)")
		}
		
		var result = [String]()
		for v in confArray {
			guard let value = v.string else {
				throw InvalidArgumentError(message: "The conf file contains an invalid value for key \(yamlName) (one of the value is not a string)")
			}
			result.append(value)
		}
		return result
	}
	
	static func stringStringDicFrom(yamlConfig: Yaml, yamlName: String) throws -> [String: String] {
		guard let confDic = yamlConfig[Yaml.string(yamlName)].dictionary else {
			throw InvalidArgumentError(message: "The conf file has an invalid value (not a dictionary) for key \(yamlName)")
		}
		
		var result = [String: String]()
		for (k, v) in confDic {
			guard let alias = k.string else {
				throw InvalidArgumentError(message: "The conf file contains an invalid value for key \(yamlName) (one of the key is not a string)")
			}
			guard let actual = v.string else {
				throw InvalidArgumentError(message: "The conf file contains an invalid value for key \(yamlName) (one of the value is not a string)")
			}
			result[alias] = actual
		}
		return result
	}
	
}
