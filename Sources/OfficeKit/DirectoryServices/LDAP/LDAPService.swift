/*
 * LDAPService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/05/2019.
 */

import Foundation

import Async
import GenericJSON
import SemiSingleton
import Service



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
	
	public init(config c: LDAPServiceConfig, domainAliases aliases: [String: String]) {
		config = c
		domainAliases = aliases
	}
	
	public func string(from userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(from string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func shortDescription(from user: LDAPInetOrgPersonWithObject) -> String {
		return user.userId.stringValue
	}
	
	public func exportableJSON(from user: LDAPInetOrgPersonWithObject) throws -> JSON {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromEmail email: Email) throws -> LDAPInetOrgPersonWithObject? {
		guard let peopleBaseDNPerDomain = config.peopleBaseDNPerDomain else {
			throw InvalidArgumentError(message: "Cannot get logical user from \(email) when I don’t have people base DNs.")
		}
		guard let baseDN = peopleBaseDNPerDomain[email.domain] else {
			/* If the domain of the email is not supported in the LDAP config, we
			 * return a nil logical user: the user cannot exist in the LDAP in this
			 * state, but it’s not an actual error.
			 * TODO: Make sure we actually do want that and not raise a “well-
			 *       known” error instead, that clients could catch… */
			return nil
		}
		let inetOrgPerson = LDAPInetOrgPerson(
			dn: LDAPDistinguishedName(uid: email.username, baseDN: baseDN),
			sn: [], cn: []
		)
		inetOrgPerson.mail = [email]
		return LDAPInetOrgPersonWithObject(inetOrgPerson: inetOrgPerson)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType) throws -> LDAPInetOrgPersonWithObject? {
		if let user: GoogleUser = user.unboxed() {
			let person = try logicalUser(fromEmail: user.primaryEmail)?.inetOrgPerson
			if let fn = user.name.value?.familyName {person?.sn = [fn]}
			if let fn = user.name.value?.fullName   {person?.cn = [fn]}
			if let gn = user.name.value?.givenName  {person?.givenName = [gn]}
			return person.flatMap{ LDAPInetOrgPersonWithObject(inetOrgPerson: $0) }
		}
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject?> {
		throw NotImplementedError()
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject?> {
		throw NotImplementedError()
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[LDAPInetOrgPersonWithObject]> {
		let ldapConnector: LDAPConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		return ldapConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ in
			let futures = self.config.allBaseDNs.map{ dn -> Future<[LDAPInetOrgPersonWithObject]> in
				let searchOp = SearchLDAPOperation(ldapConnector: ldapConnector, request: LDAPSearchRequest(scope: .children, base: dn, searchQuery: nil, attributesToFetch: nil))
				return Future<[LDAPInetOrgPerson]>.future(from: searchOp, eventLoop: container.eventLoop).map{
					$0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) }
				}
			}
			/* Merging all the users from all the domains. */
			return Future.reduce([LDAPInetOrgPersonWithObject](), futures, eventLoop: container.eventLoop, +)
		}
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: LDAPInetOrgPersonWithObject, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject> {
		let ldapConnector: LDAPConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let op = CreateLDAPObjectsOperation(objects: [user.object], connector: ldapConnector)
		return ldapConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ in
			Future<[LDAPObject]>.future(from: op, eventLoop: container.eventLoop).map{ results in
				guard let result = results.first, results.count == 1 else {
					throw InternalError(message: "Got no or more than one result from a CreateLDAPObjectsOperation that creates only one user.")
				}
				let object = try result.get()
				guard let person = LDAPInetOrgPerson(object: object) else {
					throw InternalError(message: "Cannot get an inet org person from the created object. The object may have been created on the LDAP.")
				}
				return LDAPInetOrgPersonWithObject(inetOrgPerson: person)
			}
		}
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: LDAPInetOrgPersonWithObject, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: LDAPInetOrgPersonWithObject, on container: Container) throws -> Future<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: LDAPInetOrgPersonWithObject, on container: Container) throws -> ResetPasswordAction {
		let semiSingletonStore: SemiSingletonStore = try container.make()
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user.userId, additionalInitInfo: ldapConnector) as ResetLDAPPasswordAction
	}
	
	public func authenticate(userId dn: LDAPDistinguishedName, challenge checkedPassword: String, on container: Container) throws -> Future<Bool> {
		return container.eventLoop.future()
		.map{ _ in
			guard !checkedPassword.isEmpty else {throw Error.passwordIsEmpty}
			
			var ldapConnectorConfig = self.config.connectorSettings
			ldapConnectorConfig.authMode = .userPass(username: dn.stringValue, password: checkedPassword)
			return try LDAPConnector(key: ldapConnectorConfig)
		}
		.then{ (connector: LDAPConnector) in
			return connector.connect(scope: (), forceReconnect: true, eventLoop: container.eventLoop).map{ true }
		}
		.catchMap{ error in
			if LDAPConnector.isInvalidPassError(error) {
				return false
			}
			throw error
		}
	}
	
	public func validateAdminStatus(userId: LDAPDistinguishedName, on container: Container) throws -> Future<Bool> {
		let adminGroupsDN = config.adminGroupsDN
		guard adminGroupsDN.count > 0 else {return container.eventLoop.future(false)}
		
		let ldapConnector: LDAPConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let searchQuery = LDAPSearchQuery.or(adminGroupsDN.map{
			LDAPSearchQuery.simple(attribute: .memberof, filtertype: .equal, value: Data($0.stringValue.utf8))
		})
		
		return ldapConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ -> Future<[LDAPInetOrgPersonWithObject]> in
			let op = SearchLDAPOperation(ldapConnector: ldapConnector, request: LDAPSearchRequest(scope: .subtree, base: userId, searchQuery: searchQuery, attributesToFetch: nil))
			return Future<[LDAPInetOrgPerson]>.future(from: op, eventLoop: container.eventLoop).map{ $0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) } }
		}
		.thenThrowing{ objects -> Bool in
			guard objects.count <= 1 else {
				throw Error.tooManyUsersFound
			}
			guard let inetOrgPerson = objects.first else {
				return false
			}
			return inetOrgPerson.userId == userId
		}
	}
	
	public func fetchProperties(_ properties: Set<String>?, from dn: LDAPDistinguishedName, on container: Container) throws -> Future<[String: [Data]]> {
		let ldapConnector: LDAPConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let searchRequest = LDAPSearchRequest(scope: .singleLevel, base: dn, searchQuery: nil, attributesToFetch: properties)
		let op = SearchLDAPOperation(ldapConnector: ldapConnector, request: searchRequest)
		return ldapConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ in
			return Future<[LDAPInetOrgPerson]>.future(from: op, eventLoop: container.eventLoop).map{ $0.results }
		}
		.thenThrowing{ ldapObjects in
			guard ldapObjects.count <= 1             else {throw Error.tooManyUsersFound}
			guard let ldapObject = ldapObjects.first else {throw Error.userNotFound}
			return ldapObject.attributes
		}
	}
	
	public func fetchUniqueEmails(from user: LDAPInetOrgPersonWithObject, deduplicateAliases: Bool = true, on container: Container) throws -> Future<Set<Email>> {
		#warning("TODO: Consider whether we want to use the emails already in the user (if applicable)")
		return try fetchProperties([LDAPInetOrgPerson.propNameMail], from: user.userId, on: container)
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
