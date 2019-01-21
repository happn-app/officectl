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
	var officeKitConfig: OfficeKitConfig
	
	init(flags f: Flags) throws {
		let configYaml: Yaml?
		let configPathFromFlags = f.getString(name: "config-url")
		let configPath = configPathFromFlags ?? "/etc/officectl/config.yaml"
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
		
		staticDataDirURL = (configYaml?["static_data_dir"].string ?? f.getString(name: "static-data-dir")).flatMap{ URL(fileURLWithPath: $0, isDirectory: true) }
		officeKitConfig = try OfficeKitConfig(flags: f, yamlConfig: configYaml)
	}
	
}
