/*
 * CloudflareServiceConfig.swift
 * CloudflareOffice
 *
 * Created by François Lamboley on 2023/07/25.
 */

import Foundation

import GenericJSON

import OfficeKit



public struct CloudflareServiceConfig : Sendable, Codable {
	
	public var accountID: String
	public var connectorSettings: ConnectorSettings
	
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var token: String
		
		private enum CodingKeys : String, CodingKey {
			
			case token
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case accountID = "account_id"
		case connectorSettings = "connector_settings"
		
		case userIDBuilders = "user_id_builders"
		
	}
	
}
