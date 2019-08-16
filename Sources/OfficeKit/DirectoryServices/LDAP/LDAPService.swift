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
	
	public init(config c: LDAPServiceConfig) {
		config = c
	}
	
	public func shortDescription(from user: LDAPInetOrgPersonWithObject) -> String {
		return user.userId.stringValue
	}
	
	public func string(fromUserId userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentId pId: LDAPDistinguishedName) -> String {
		return pId.stringValue
	}
	
	public func persistentId(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func json(fromUser user: LDAPInetOrgPersonWithObject) throws -> JSON {
		return JSON.object(user.object.attributes.mapValues{ values in
			JSON.array(values.map{ valueData in
				if let valueString = String(data: valueData, encoding: .utf8) {
					return JSON.object(["str": JSON.string(valueString)])
				} else {
					return JSON.object(["dta": JSON.string(valueData.base64EncodedString())])
				}
			})
		}.merging(["dn": JSON.string(user.inetOrgPerson.dn.stringValue)], uniquingKeysWith: { (_, new) in new }))
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> LDAPInetOrgPersonWithObject {
		let taggedId = userWrapper.userId
		if taggedId.tag == config.serviceId/*, let underlying = userWrapper.underlyingUser*/ {
			/* The generic user is from our service! We should be able to translate
			 * if fully to our User type. */
			guard let dn = try? LDAPDistinguishedName(string: taggedId.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but which does not have a valid dn.")
			}
			#warning("TODO: The rest of the properties (from the underlying user).")
			return LDAPInetOrgPersonWithObject(inetOrgPerson: LDAPInetOrgPerson(dn: dn, sn: [], cn: []))
			
		} else {
			guard let email = userWrapper.mainEmail(domainMap: config.global.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create an LDAPInetOrgPersonWithObject")
			}
			guard let dn = config.baseDNs.dn(fromEmail: email) else {
				throw InvalidArgumentError(message: "Cannot get dn from \(email).")
			}
			#warning("TODO: The rest of the properties.")
			return LDAPInetOrgPersonWithObject(inetOrgPerson: LDAPInetOrgPerson(dn: dn, sn: [], cn: []))
		}
	}
	
	public func existingUser(fromPersistentId pId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<LDAPInetOrgPersonWithObject?> {
		let ldapConnector: LDAPConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		return ldapConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ in
			#warning("TODO: Implement properties to fetch")
			let searchOp = SearchLDAPOperation(ldapConnector: ldapConnector, request: LDAPSearchRequest(scope: .base, base: uId, searchQuery: nil, attributesToFetch: nil))
			return Future<[LDAPInetOrgPerson]>.future(from: searchOp, eventLoop: container.eventLoop).map{ searchResults in
				let c = searchResults.results.count
				guard let object = searchResults.results.first, c == 1 else {
					throw c == 0 ? Error.userNotFound : Error.tooManyUsersFound
				}
				guard let ret = LDAPInetOrgPersonWithObject(object: object) else {
					throw Error.internalError
				}
				return ret
			}
		}
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[LDAPInetOrgPersonWithObject]> {
		let ldapConnector: LDAPConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		return ldapConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ in
			let futures = self.config.baseDNs.allBaseDNs.map{ dn -> Future<[LDAPInetOrgPersonWithObject]> in
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
				guard let result = results.onlyElement else {
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
		
		let searchRequest = LDAPSearchRequest(scope: .base, base: dn, searchQuery: nil, attributesToFetch: properties)
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
			return Set(emails.map{ $0.primaryDomainVariant(aliasMap: self.config.global.domainAliases) })
		}
	}
	
}
