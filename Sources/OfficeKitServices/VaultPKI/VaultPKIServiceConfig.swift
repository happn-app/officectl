/*
 * VaultPKIServiceConfig.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import GenericJSON

import OfficeKit



public struct VaultPKIServiceConfig : Sendable, Codable {
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var rootToken: String
		
		private enum CodingKeys : String, CodingKey {
			
			case rootToken = "root_token"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
