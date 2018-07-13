/*
 * GetConnectedGoogleConnector.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import Guaka
import RetryingOperation



public class GetConnectedGoogleConnector : RetryingOperation {
	
	public let scope: Set<String>
	
	public let connector: GoogleJWTConnector
	public var connectionError: Error?
	
	public convenience init(flags f: Flags, scope s: Set<String>, userBehalf: String?) throws {
		guard let credsURLString = f.getString(name: "google-superuser-json-creds") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The google-superuser-json-creds argument is required for commands dealing with Google APIs"])
		}
		guard let c = GoogleJWTConnector(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create the Google connector (does the credentials file exist?)"])
		}
		self.init(connector: c, scope: s)
	}
	
	public init(connector c: GoogleJWTConnector, scope s: Set<String>) {
		scope = s
		connector = c
		
		super.init()
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		connector.connect(scope: scope, handler: { error in
			if !self.connector.isConnected {
				self.connectionError = error ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown Google connection error"])
			}
			self.baseOperationEnded()
		})
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
}
