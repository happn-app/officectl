/*
 * WrappedUserToUserIdConversionStrategy.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/16.
 */

import Foundation

import GenericStorage



public enum WrappedUserToUserIdConversionStrategy : Hashable {
	
	case emailToTaggedDN(baseDNs: LDAPBaseDNs, tag: String?)
	
	public init(genericStorage: GenericStorage, currentKeyPath: [String] = []) throws {
		switch try genericStorage.string(forKey: "type", currentKeyPath: currentKeyPath) {
			case "emailToTaggedDN":
				let tag       = try genericStorage.optionalString(forKey: "tag", currentKeyPath: currentKeyPath)
				let bdnDic    = try genericStorage.dictionaryOfStrings(forKey: "base_dn_per_domains", currentKeyPath: currentKeyPath)
				let pdnString = try genericStorage.optionalString(forKey: "people_dn", currentKeyPath: currentKeyPath)
				let baseDNs = try LDAPBaseDNs(baseDNPerDomainString: bdnDic, peopleDNString: pdnString)
				self = .emailToTaggedDN(baseDNs: baseDNs, tag: tag)
				
			default:
				throw InvalidArgumentError(message: "Unknown WrappedUserToUserIdConversionStrategy type")
		}
	}
	
	public func convertUserToId(_ userWrapper: DirectoryUserWrapper, globalConfig: GlobalConfig) throws -> String {
		switch self {
			case .emailToTaggedDN(baseDNs: let baseDNs, tag: let tag):
				guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
					throw InvalidArgumentError(message: "Cannot get an email from the user to apply emailToTaggedDN conversion strategy")
				}
				guard let dn = baseDNs.dn(fromEmail: email) else {
					throw InvalidArgumentError(message: "Cannot get dn from \(email).")
				}
				return (tag.flatMap{ $0 + ":" } ?? "") + dn.stringValue
		}
	}
	
}
