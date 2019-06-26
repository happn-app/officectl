/*
 * OfficeKitServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Vapor



struct ConfigError : Error {
	
	let domain: String?
	let key: String
	let message: String
	
}

public protocol GenericConfig {
	
	/* For all this methods, the domain is only needed to generate the
	 * ConfigError when applicable. */
	
	func string(for key: String, domain: String?) throws -> String
	func optionalString(for key: String, domain: String?) throws -> String?
	
	func arrayOfString(for key: String, domain: String?) throws -> [String]
	func optionalStringArray(for key: String, domain: String?) throws -> [String]?
	
	func stringStringDic(for key: String, domain: String?) throws -> [String: String]
	func optionalStringStringDic(for key: String, domain: String?) throws -> [String: String]?
	
	func stringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig]
	func optionalStringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig]?
	
}

public protocol OfficeKitServiceConfig : Hashable {
	
	/** The id of the linked provider, e.g. "internal_openldap". Those are static
	in OfficeKit. */
	static var providerId: String {get}
	
	/** The id of the instance of the provider, e.g. "happn_ldap". Defined by the
	caller. */
	var serviceId: String {get}
	var serviceName: String {get}
	
	init(serviceId: String, serviceName: String, genericConfig: GenericConfig) throws
	
}
