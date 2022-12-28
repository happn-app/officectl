/*
 * GitHubServiceConfig.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/28.
 */

import Foundation

import GenericJSON

import OfficeKit2



public struct GitHubServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var appID: String
		public var installationID: String
		public var privateKeyPath: String
		
		private enum CodingKeys : String, CodingKey {
			
			case appID = "app_id"
			case installationID = "installation_id"
			case privateKeyPath = "private_key_path"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_name"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
