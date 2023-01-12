/*
 * OfficeKitServiceConfig.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import GenericJSON

import OfficeKit



public struct OfficeKitServiceConfig : Sendable, Codable {
	
	public var serviceName: String
	
	public var upstreamURL: URL
	public var secret: Data
	
	public var supportedProperties: Set<UserProperty>
	public var supportsUserCreation: Bool
	public var supportsUserUpdate: Bool
	public var supportsUserDeletion: Bool
	public var supportsPasswordChange: Bool
	
	public var userIDBuilders: [UserIDBuilder]?
	public var alternateUserIDsBuilders: [UserIDBuilder]?
	
	public init(json: JSON) throws {
		let data = try JSONEncoder().encode(json)
		self = try JSONDecoder().decode(Self.self, from: data)
	}
	
	private enum CodingKeys : String, CodingKey {
		
		case serviceName = "service_name"
		
		case upstreamURL = "upstream_url"
		case secret = "secret"
		
		case supportedProperties = "supported_properties"
		case supportsUserCreation = "supports_user_creation"
		case supportsUserUpdate = "supports_user_update"
		case supportsUserDeletion = "supports_user_deletion"
		case supportsPasswordChange = "supports_password_change"
		
		case userIDBuilders = "user_id_builders"
		case alternateUserIDsBuilders = "alternate_user_ids_builders"
		
	}
	
}
