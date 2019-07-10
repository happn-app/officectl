/*
 * OfficeKitServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation



public struct ConfigError : Error {
	
	public let domain: String?
	public let key: String
	public let message: String
	
	public init(domain d: String?, key k: String, message m: String) {
		domain = d
		key = k
		message = m
	}
	
}

public protocol GenericConfig {
	
	/* For all this methods, the domain is only needed to generate the
	 * ConfigError when applicable. */
	
	func bool(for key: String, domain: String?) throws -> Bool
	func optionalBool(for key: String, domain: String?) throws -> Bool?
	
	func int(for key: String, domain: String?) throws -> Int
	func optionalInt(for key: String, domain: String?) throws -> Int?
	
	func string(for key: String, domain: String?) throws -> String
	func optionalString(for key: String, domain: String?) throws -> String?
	
	func url(for key: String, domain: String?) throws -> URL
	func optionalURL(for key: String, domain: String?) throws -> URL?
	
	func stringArray(for key: String, domain: String?) throws -> [String]
	func optionalStringArray(for key: String, domain: String?) throws -> [String]?
	
	func stringStringDic(for key: String, domain: String?) throws -> [String: String]
	func optionalStringStringDic(for key: String, domain: String?) throws -> [String: String]?
	
	func stringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig]
	func optionalStringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig]?
	
	func genericConfig(for key: String, domain: String?) throws -> GenericConfig
	func optionalGenericConfig(for key: String, domain: String?) throws -> GenericConfig?
	
}

public protocol OfficeKitServiceConfig : Hashable {
	
	/** The provider id for which the config is for. */
	var providerId: String {get}
	
	/** The id of the instance of the provider, e.g. "happn_ldap". Defined by the
	caller.
	
	Restrictions on the id:
	- It **cannot contain a colon** (“:”)
	- It **cannot be equal to “email”** (email is a reserved name).
	
	You must fail a config init with a serviceId that do not respect these
	requirements. */
	var serviceId: String {get}
	var serviceName: String {get}
	
}
