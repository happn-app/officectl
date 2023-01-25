/*
 * Office365ServiceConfig.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import GenericJSON

import OfficeKit



public struct Office365ServiceConfig : Sendable, Codable {
	
//	public var primaryDomains: [String]
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public enum Grant : Sendable, Codable {
			case clientSecret(value: String)
			/* Here’s the command line to get the x5t:
			 *    `openssl x509 -in "$CERT.crt" -fingerprint -sha1 -noout | sed -E -e 's/SHA[0-9]+ Fingerprint=//g' -e 's/://g' | xxd -r -ps | base64`
			 * Important: The x5t should be base64 _URL_ encoded.
			 * Simply remove the trailing “=” and replace “+” with “-” and “/” with “_”. */
			case clientCertificate(x5t: String, privateKeyPath: String)
		}
		
		public var tenantID: String
		public var clientID: String
		public var grant: Grant
		
		private enum CodingKeys : String, CodingKey {
			
			case tenantID = "tenant_id"
			case clientID = "client_id"
			case grant
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
//		case primaryDomains = "primary_domains"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
