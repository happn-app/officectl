/*
 * HappnServiceConfig.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 * 
 */

import Foundation

import GenericJSON



public struct HappnServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	public var connectorSettings: ConnectorSettings
	
	init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var baseURL: URL
		
		public var clientID: String
		public var clientSecret: String
		
		public var adminUsername: String
		public var adminPassword: String
		
		private enum CodingKeys : String, CodingKey {
			
			case baseURL = "base_url"
			case clientID = "client_id", clientSecret = "client_secret"
			case adminUsername = "admin_username", adminPassword = "admin_password"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_id"
		case connectorSettings = "connector_settings"
		
	}
	
}
