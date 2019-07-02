/*
 * LDAPService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/05/2019.
 */

import Foundation

import Async
import SemiSingleton



public final class LDAPService : DirectoryService, DirectoryAuthenticatorService {
	
	public static var providerId = "internal_openldap"
	
	public enum Error : Swift.Error {
		
		case invalidEmailInLDAP
		
		case userNotFound
		case tooManyUsersFound
		
		case passwordIsEmpty
		
		case unsupportedServiceUserIdConversion
		
		case internalError
		
	}
	
	public typealias ConfigType = LDAPServiceConfig
	public typealias UserType = LDAPInetOrgPersonWithObject
	public typealias AuthenticationChallenge = String
	
	public let config: LDAPServiceConfig
	public let domainAliases: [String: String]
	
	public init(config c: LDAPServiceConfig, domainAliases aliases: [String: String], semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		config = c
		domainAliases = aliases
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		ldapConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func logicalUser(from email: Email) throws -> LDAPInetOrgPersonWithObject {
		throw NotImplementedError()
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> LDAPInetOrgPersonWithObject {
		throw NotImplementedError()
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<LDAPInetOrgPersonWithObject?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<LDAPInetOrgPersonWithObject?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public func listAllUsers() -> Future<[LDAPInetOrgPersonWithObject]> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: LDAPInetOrgPersonWithObject) -> Future<LDAPInetOrgPersonWithObject> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: LDAPInetOrgPersonWithObject, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<LDAPInetOrgPersonWithObject> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: LDAPInetOrgPersonWithObject) -> Future<Void> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: LDAPInetOrgPersonWithObject) throws -> ResetPasswordAction {
		return semiSingletonStore.semiSingleton(forKey: user.id, additionalInitInfo: (asyncConfig, ldapConnector)) as ResetLDAPPasswordAction
	}
	
	public func authenticate(user dn: LDAPDistinguishedName, challenge checkedPassword: String) -> Future<Bool> {
		return asyncConfig.eventLoop.future()
		.thenThrowing{ _ in
			guard !checkedPassword.isEmpty else {throw Error.passwordIsEmpty}
			
			var ldapConnectorConfig = self.config.connectorSettings
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
	
	public func isUserAdmin(_ user: LDAPDistinguishedName) -> Future<Bool> {
		let adminGroupsDN = config.adminGroupsDN
		guard adminGroupsDN.count > 0 else {return asyncConfig.eventLoop.future(false)}
		
		let searchQuery = LDAPSearchQuery.or(adminGroupsDN.map{
			LDAPSearchQuery.simple(attribute: .memberof, filtertype: .equal, value: Data($0.stringValue.utf8))
		})
		
		return ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> Future<[LDAPInetOrgPersonWithObject]> in
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
			return inetOrgPerson.id == user
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
	
	public func fetchUniqueEmails(from user: LDAPInetOrgPersonWithObject, deduplicateAliases: Bool = true) -> Future<Set<Email>> {
		#warning("TODO: Consider whether we want to use the emails already in the user (if applicable)")
		return fetchProperties([LDAPInetOrgPerson.propNameMail], from: user.id)
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
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let ldapConnector: LDAPConnector
	
}
