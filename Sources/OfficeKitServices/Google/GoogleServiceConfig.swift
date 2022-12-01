/*
 * GoogleServiceConfig.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation

import Email
import GenericJSON

import OfficeKit2



public struct GoogleServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	
	public var primaryDomains: [String]
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var adminEmail: Email?
		public var superuserJSONCredsPath: String
		
		private enum CodingKeys : String, CodingKey {
			
			case adminEmail = "admin_email"
			case superuserJSONCredsPath = "superuser_json_creds_path"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_name"
		
		case primaryDomains = "primary_domains"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
