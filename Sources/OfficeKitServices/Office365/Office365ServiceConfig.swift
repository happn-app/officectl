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
		
		public var tenantID: String
		public var clientID: String
		public var clientSecret: String
		/* Could be generated with:
		 *   `openssl x509 -in "$CERT.crt" -fingerprint -noout | sed -E -e 's/SHA[0-9]+ Fingerprint=//g' -e 's/://g' | xxd -r -ps | base64`
		 * One day maybe we’ll just ask for the path of the certif and do the computation in the code directly, but this day has not come yet!
		 * For now we do not use this as the JWT framework does not allow adding custom fields in the header and does not support the “x5t” field.
		 *
		 * Further investigations:
		 * - It seems the x5t generated with the command above might be incorrect;
		 * - The x5t can be retrieved from this URL: <https://login.microsoftonline.com/TENANT_ID/discovery/v2.0/keys>;
		 * - The kid field is accepted in place of the x5t apparently.
		 * - Nothing works anyway; we try with a client secret for now. */
//		public var certificateX5t: String
//		public var privateKeyPath: String

		private enum CodingKeys : String, CodingKey {
			
			case tenantID = "tenant_id"
			case clientID = "client_id"
			case clientSecret = "client_secret"
//			case certificateX5t = "certificate_x5t"
//			case privateKeyPath = "private_key_path"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
//		case primaryDomains = "primary_domains"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
