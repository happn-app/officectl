/*
 * HappnServiceConfig.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 * 
 */

import Foundation

import GenericJSON

import OfficeKit2



public struct HappnServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]
	
	/* A map of domain aliases to actual domain.
	 * E.g. for map ["happn.fr": "happn.com"], the "happn.fr" domain will be considered an alias of the "happn.com" domain.
	 * This means a user can be found whether it is searched using the happn.fr or happn.com domain. */
	public var domainAliases: [String: String]?
	
	public init(json: JSON) throws {
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
		
		case serviceName = "service_name"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
		case domainAliases = "domain_aliases"
		
	}
	
}
