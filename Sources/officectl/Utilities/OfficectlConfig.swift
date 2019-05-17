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
	
	var officeKitConfig: OfficeKitConfig
	
	init(flags f: Flags) throws {
		let configYaml: Yaml?
		let configPathFromFlags = f.getString(name: "config-file")
		let configPath = configPathFromFlags ?? "/etc/officectl/officectl.yaml"
		if FileManager.default.fileExists(atPath: configPath) {
			let configString = try String(contentsOfFile: configPath, encoding: .utf8)
			configYaml = try Yaml.load(configString)
		} else {
			/* The config file does not exist at configPath. If the user
			 * specifically gave us a config path, we fail the init: we assume the
			 * user does want to read its config file when given in parameter. If
			 * we use the default config path, we assume the user might have given
			 * all the needed parameters through the command line option and ignore
			 * the missing file. */
			if let p = configPathFromFlags {
				throw InvalidArgumentError(message: "File not found at given config path: \(p)")
			}
			configYaml = nil
		}
		
		staticDataDirURL = (f.getString(name: "static-data-dir") ?? configYaml?["server"]["static_data_dir"].string).flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
		serverHost = f.getString(name: "hostname") ?? configYaml?["server"]["hostname"].string ?? "localhost"
		serverPort = f.getInt(name: "port") ?? configYaml?["server"]["port"].int ?? 8080
		
		guard let jSecret = f.getString(name: "jwt-secret") ?? configYaml?["server"]["jwt_secret"].string else {
			throw MissingFieldError("JWT Secret")
		}
		jwtSecret = jSecret
		
		verbose = f.getBool(name: "verbose") ?? false
		
		officeKitConfig = try OfficeKitConfig(flags: f, yamlConfig: configYaml)
	}
	
}



/* Conveniences for retrieving some options */
extension OfficectlConfig {
	
	static func stringStringDicFrom(flags: Flags, yamlConfig: Yaml?, flagName: String, yamlName: String?) throws -> [String: String]? {
		let ret: [String: String]?
		if let aliasesStr = flags.getString(name: flagName) {
			/* Let’s parse the aliases */
			let parseError = InvalidArgumentError(message: "The \(flagName) argument should be of the form “key:value;...”")
			
			var result = [String: String]()
			let aliasesSplit = aliasesStr.split(separator: ";").map{ $0.split(separator: ":") }
			for aliasCouple in aliasesSplit {
				guard aliasCouple.count == 2 else {throw parseError}
				
				let alias = String(aliasCouple[0])
				let actual = String(aliasCouple[1])
				guard !alias.isEmpty && !actual.isEmpty else {throw parseError}
				
				guard result[alias] == nil else {
					throw InvalidArgumentError(message: "Invalid \(flagName) argument: duplicate entry found for \(alias)")
				}
				
				result[alias] = actual
			}
			ret = result
		} else if let yamlName = yamlName, let conf = yamlConfig?[Yaml.string(yamlName)] {
			guard let confDic = conf.dictionary else {
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
			ret = result
		} else {
			ret = nil
		}
		return ret
	}
	
}
