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
