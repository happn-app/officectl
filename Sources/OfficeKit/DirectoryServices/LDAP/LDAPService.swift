/*
 * LDAPService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/05/2019.
 */

import Foundation

import Async
import SemiSingleton



public class LDAPService : DirectoryService, DirectoryServiceAuthenticator {
	
	public enum Error : Swift.Error {
		
		case invalidEmailInLDAP
		
		case userNotFound
		case tooManyUsersFound
		
		case passwordIsEmpty
		
		case unsupportedServiceUserIdConversion
		
		case internalError
		
	}
	
	public static let id = "internal_openldap"
	
	public typealias UserIdType = LDAPDistinguishedName
	public typealias AuthenticationChallenge = String
	
	public let supportsPasswordChange = true
	
	public let serviceId: String
	public let serviceName: String
	public let asyncConfig: AsyncConfig
	public let domainAliases: [String: String]
	public let ldapConfig: OfficeKitConfig.LDAPConfig
	public let semiSingletonStore: SemiSingletonStore
	
	public let ldapConnector: LDAPConnector
	
	public init(id: String, name: String, ldapConfig config: OfficeKitConfig.LDAPConfig, domainAliases aliases: [String: String], semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceId = id
		asyncConfig = ac
		serviceName = name
		ldapConfig = config
		domainAliases = aliases
		semiSingletonStore = sms
		
		ldapConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func existingUserId<T>(from userId: T.UserIdType, in service: T) -> EventLoopFuture<LDAPDistinguishedName?> where T : DirectoryService {
		return asyncConfig.eventLoop.newFailedFuture(error: Error.unsupportedServiceUserIdConversion)
	}
	
	public func changePasswordAction(for user: LDAPDistinguishedName) throws -> Action<LDAPDistinguishedName, String, Void> {
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: (asyncConfig, ldapConnector)) as ResetLDAPPasswordAction
	}
	
	public func authenticate(user dn: LDAPDistinguishedName, challenge checkedPassword: String) -> Future<Bool> {
		asyncConfig.eventLoop.future()
		.thenThrowing{ _ in
			guard !checkedPassword.isEmpty else {throw Error.passwordIsEmpty}
			
			var ldapConnectorConfig = self.ldapConfig.connectorSettings
			ldapConnectorConfig.authMode = .userPass(username: dn.stringValue, password: checkedPassword)
			return try LDAPConnector(key: ldapConnectorConfig)
		}
		.then{ (connector: LDAPConnector) in
			return connector.connect(scope: (), forceReconnect: true, asyncConfig: self.asyncConfig).map{ true }
		}
		.catchMap{ error in
			if LDAPConnector.isInvalidPassError(error) {
				return false
			}
			throw error
		}
	}
	
	public func isAdmin(_ user: LDAPDistinguishedName) -> Future<Bool> {
		let adminGroupsDN = ldapConfig.adminGroupsDN
		guard adminGroupsDN.count > 0 else {return asyncConfig.eventLoop.future(false)}
		
		let searchQuery = LDAPSearchQuery.or(adminGroupsDN.map{
			LDAPSearchQuery.simple(attribute: .memberof, filtertype: .equal, value: Data($0.stringValue.utf8))
		})
		
		return ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[LDAPInetOrgPersonWithObject]> in
			let op = SearchLDAPOperation(ldapConnector: self.ldapConnector, request: LDAPSearchRequest(scope: .subtree, base: user, searchQuery: searchQuery, attributesToFetch: nil))
			return self.asyncConfig.eventLoop.future(from: op, queue: self.asyncConfig.operationQueue).map{ $0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) } }
		}
		.thenThrowing{ objects -> Bool in
			guard objects.count <= 1 else {
				throw Error.tooManyUsersFound
			}
			guard let inetOrgPerson = objects.first else {
				return false
			}
			return inetOrgPerson.object.parsedDistinguishedName == user
		}
	}
	
	public func fetchProperties(_ properties: Set<String>?, from dn: LDAPDistinguishedName) -> Future<[String: [Data]]> {
		let searchRequest = LDAPSearchRequest(scope: .singleLevel, base: dn, searchQuery: nil, attributesToFetch: properties)
		let op = SearchLDAPOperation(ldapConnector: ldapConnector, request: searchRequest)
		return ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ in
			return self.asyncConfig.eventLoop.future(from: op, queue: self.asyncConfig.operationQueue).map{ $0.results }
		}
		.thenThrowing{ ldapObjects in
			guard ldapObjects.count <= 1             else {throw Error.tooManyUsersFound}
			guard let ldapObject = ldapObjects.first else {throw Error.userNotFound}
			return ldapObject.attributes
		}
	}
	
	public func fetchUniqueEmails(from dn: LDAPDistinguishedName, deduplicateAliases: Bool = true) -> Future<Set<Email>> {
		return fetchProperties([LDAPInetOrgPerson.propNameMail], from: dn)
		.map{ properties in
			guard let emailDataArray = properties[LDAPInetOrgPerson.propNameMail] else {
				throw Error.internalError
			}
			let emails = try emailDataArray.map{ emailData -> Email in
				guard let emailStr = String(data: emailData, encoding: .utf8), let email = Email(string: emailStr) else {
					throw Error.invalidEmailInLDAP
				}
				return email
			}
			/* Deduplication */
			if !deduplicateAliases {return Set(emails)}
			return Set(emails.map{ $0.primaryDomainVariant(aliasMap: self.domainAliases) })
		}
	}
	
}
