/*
 * OfficeKitConfig+CLIUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/01/2019.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



extension OfficeKitConfig : Service {
	
	init(flags f: Flags) {
		self.init(
			ldapConfig: LDAPConfig(flags: f),
			googleConfig: GoogleConfig(flags: f),
			gitHubConfig: GitHubConfig(flags: f)
		)
	}
	
}
