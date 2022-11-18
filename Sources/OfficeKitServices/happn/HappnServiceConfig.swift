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
	
	/* We set a random default value because we don’t want this to be part of the Codable representation,
	 *  but we don’t want an invalid id by default either. */
	public var serviceID: String = UUID().uuidString
	public var serviceName: String
	public var connectorSettings: ConnectorSettings
	
	init(serviceID: String, json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
		self.serviceID = serviceID
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var clientID: String
		public var clientSecret: String
		
		public var username: String
		public var password: String
		
		private enum CodingKeys : String, CodingKey {
			
			case clientID = "client_id", clientSecret = "client_secret"
			case username, password
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_id"
		case connectorSettings = "connector_settings"
		
	}
	
}
