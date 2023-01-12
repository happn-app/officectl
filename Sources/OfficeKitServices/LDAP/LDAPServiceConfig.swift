/*
 * LDAPServiceConfig.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import GenericJSON

import OfficeKit



public struct LDAPServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	
	public var baseDN: LDAPDistinguishedName
	public var peopleDN: LDAPDistinguishedName
	public var groupsDN: LDAPDistinguishedName?
	
	public var connectorSettings: ConnectorSettings
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct ConnectorSettings : Sendable, Codable {
		
		public var ldapURL: URL
		public var ldapVersion: LDAPConnector.ProtocolVersion
		public var startTLS: Bool
		
		public var auth: LDAPConnector.Auth?
		
		private enum CodingKeys : String, CodingKey {
			
			case ldapURL = "ldap_url"
			case ldapVersion = "ldap_version"
			case startTLS = "start_tls"
			
			case auth
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_name"
		
		case baseDN = "base_dn"
		case peopleDN = "people_dn"
		case groupsDN = "groups_dn"
		
		case connectorSettings = "connector_settings"
		case userIDBuilders = "user_id_builders"
		
	}
	
}
