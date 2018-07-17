/*
 * GoogleJWTConnector+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import Guaka

import OfficeKit



extension GoogleJWTConnector {
	
	convenience init(flags f: Flags, userBehalf: String?) throws {
		guard let credsURLString = f.getString(name: "google-superuser-json-creds") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The google-superuser-json-creds argument is required for commands dealing with Google APIs"])
		}
		try self.init(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
	}
	
}
