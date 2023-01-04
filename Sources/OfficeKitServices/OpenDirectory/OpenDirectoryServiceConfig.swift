/*
 * OpenDirectoryService.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/03.
 */

import Foundation

import GenericJSON

import OfficeKit2



public struct OpenDirectoryServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var proxySettings: OpenDirectoryConnector.ProxySettings?
		
		public var nodeType: OpenDirectoryConnector.NodeType
		public var nodeCredentials: OpenDirectoryConnector.NodeCredentials
		
		private enum CodingKeys : String, CodingKey {
			
			case proxySettings = "proxy_settings"
			
			case nodeType = "node_type"
			case nodeCredentials = "node_credentials"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_name"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
