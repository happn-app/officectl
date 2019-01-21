/*
 * OfficeKitConfig+CLIUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation

import Guaka
import Vapor
import Yaml

import OfficeKit



extension OfficeKitConfig : Service {
	
	init(flags f: Flags, yamlConfig: Yaml?) throws {
		self.init(
			ldapConfig: try LDAPConfig(flags: f, yamlConfig: yamlConfig),
			googleConfig: try GoogleConfig(flags: f, yamlConfig: yamlConfig),
			gitHubConfig: try GitHubConfig(flags: f, yamlConfig: yamlConfig)
		)
	}
	
}
