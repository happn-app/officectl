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
	
	public var baseURL: URL
	public var issuerName: String
	public var additionalActiveIssuers: Set<String>
	public var additionalPassiveIssuers: Set<String>
	public var additionalCertificateIDs: Set<String>
	
	public var newCertsTTL: String
	
	public var authenticatorSettings: AuthenticatorSettings
	
	public var userIDBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	public struct AuthenticatorSettings : Sendable, Codable {
		
		public var rootToken: String
		
		private enum CodingKeys : String, CodingKey {
			
			case rootToken = "root_token"
			
		}
		
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case baseURL = "base_url"
		case issuerName = "issuer_name"
		case additionalActiveIssuers = "additional_active_issuers"
		case additionalPassiveIssuers = "additional_passive_issuers"
		case additionalCertificateIDs = "additional_certificate_ids"
		
		case newCertsTTL = "new_certs_ttl"
		
		case authenticatorSettings = "authenticator_settings"
		
		case userIDBuilders = "user_id_builders"
		
	}
	
}
