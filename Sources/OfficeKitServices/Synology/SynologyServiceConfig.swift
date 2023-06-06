/*
 * SynologyServiceConfig.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import GenericJSON

import OfficeKit



public struct SynologyServiceConfig : Sendable, Codable {
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var dsmURL: URL
		public var username: String
		public var password: String
		/* No support for OTP and co. */
		
		private enum CodingKeys : String, CodingKey {
			
			case dsmURL = "dsm_url"
			case username
			case password
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
