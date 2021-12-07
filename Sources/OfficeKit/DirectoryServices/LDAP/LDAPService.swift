/*
 * LDAPService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/05/2019.
 */

import Foundation

import Email
import GenericJSON
import NIO
import SemiSingleton
import ServiceKit



/**
 An LDAP service.
 
 Dependencies:
 - Semi-singleton store. */
public final class LDAPService : UserDirectoryService, DirectoryAuthenticatorService {
	
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
	public let globalConfig: GlobalConfig
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: LDAPInetOrgPersonWithObject) -> String {
		return user.userId.stringValue
	}
	
	public func string(fromUserId userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentUserId pId: LDAPDistinguishedName) -> String {
		return pId.stringValue
	}
	
	public func persistentUserId(fromString string: String) throws -> LDAPDistinguishedName {
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
	
	public func logicalUser(fromJSON json: JSON) throws -> LDAPInetOrgPersonWithObject {
		guard let object = json.objectValue, let dnStr = object["dn"]?.stringValue, let dn = try? LDAPDistinguishedName(string: dnStr) else {
			throw InvalidArgumentError(message: "Invalid json: does not have a valid dn value.")
		}
		let ldapObjectAttributes = try object.filter{ $0.key != "dn" }.mapValues{ value -> [Data] in
			guard case .array(let array) = value else {throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value is not an array")}
			return try array.map{ arrayValue in
				guard case .object(let object) = arrayValue else {throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value has a non-object element")}
				guard object.count == 1 else {throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value has an object containing more than one element")}
				if let strValue = object["str"]?.stringValue {
					return Data(strValue.utf8)
				} else if let dataStrValue = object["dta"]?.stringValue {
					guard let data = Data(base64Encoded: dataStrValue) else {
						throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value has an object whose \"dta\" key does not contain valid base64 data.")
					}
					return data
				} else {
					throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value has an object which does not contain a valid \"str\" or \"dta\" key.")
				}
			}
		}
		let ldapObject = LDAPObject(distinguishedName: dn, attributes: ldapObjectAttributes)
		guard let ret = LDAPInetOrgPersonWithObject(object: ldapObject) else {
			throw InvalidArgumentError(message: "Cannot create a valid LDAPInetOrgPersonWithObject with the given attributes")
		}
		return ret
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> LDAPInetOrgPersonWithObject {
		if userWrapper.sourceServiceId == config.serviceId, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserId: LDAPDistinguishedName
		if userWrapper.sourceServiceId == config.serviceId {
			/* The underlying user (though absent) is from our service; the original id can be decoded as a valid id for our service. */
			guard let dn = try? LDAPDistinguishedName(string: userWrapper.userId.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but which does not have a valid dn.")
			}
			inferredUserId = dn
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create an LDAPInetOrgPersonWithObject")
			}
			guard let dn = config.baseDNs.dn(fromEmail: email) else {
				throw InvalidArgumentError(message: "Cannot get dn from \(email).")
			}
			inferredUserId = dn
		}
		
		let lastName = userWrapper.lastName.value?.flatMap{ $0 }
		let firstName = userWrapper.firstName.value?.flatMap{ $0 }
		let fullname = fullNameFrom(firstName: firstName, lastName: lastName)
		let inetOrgPerson = LDAPInetOrgPerson(dn: inferredUserId, sn: lastName.flatMap{ [$0] } ?? [], cn: fullname.flatMap{ [$0] } ?? [])
		inetOrgPerson.givenName = firstName.flatMap{ [$0] } ?? []
		inetOrgPerson.mail = userWrapper.emails
		return LDAPInetOrgPersonWithObject(inetOrgPerson: inetOrgPerson)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout LDAPInetOrgPersonWithObject, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		var newLDAPObject = user.object
		var res = Set<DirectoryUserProperty>()
		for (property, value) in hints {
			switch property {
				case .userId:
					guard allowUserIdChange else {continue}
					guard let dn = value.flatMap({ try? LDAPDistinguishedName(string: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid value for the user id of an LDAP user; not applying hint: \(value ?? "<null>")")
						continue
					}
					newLDAPObject.distinguishedName = dn
					res.insert(.userId)
					
				case .persistentId:
					OfficeKitConfig.logger?.warning("Changing the persistent id of an LDAP user is not supported.")
					
				case .identifyingEmail:
					guard let emailStr = value else {
						if hints[.otherEmails].flatMap({ $0 }) != nil {
							OfficeKitConfig.logger?.warning("Setting all emails of LDAP user to nil even though other emails is not nil because the identifying email hint is set to nil.")
						}
						newLDAPObject.attributes[LDAPInetOrgPerson.propNameMail] = nil
						continue
					}
					guard let email = Email(rawValue: emailStr) else {
						OfficeKitConfig.logger?.warning("Invalid value for an identifying email; not applying this hint nor otherEmails: \(value ?? "<null>")")
						continue
					}
					/* Yes.
					 * We cannot represent an element in the list which contains a comma.
					 * Maybe one day we’ll do the generic thing… */
					let otherEmails: [Email]
					let otherEmailsStrArray = hints[.otherEmails]??.split(separator: ",")
					if let emails = try? otherEmailsStrArray?.map({ try nil2throw(Email(rawValue: String($0))) }) {
						otherEmails = emails
						res.insert(.otherEmails)
					} else {
						otherEmails = []
					}
					res.insert(.identifyingEmail)
					newLDAPObject.attributes[LDAPInetOrgPerson.propNameMail] = [Data(email.rawValue.utf8)] + otherEmails.map{ Data($0.rawValue.utf8) }
					
				case .otherEmails:
					if value != nil && hints[.identifyingEmail].flatMap({ $0 }) == nil {
						OfficeKitConfig.logger?.warning("Unsupported config for an LDAP user: other emails is set but identifying email is not. For an LDAP user the identifying user is the first one.")
					}
					
				case .firstName:
					newLDAPObject.attributes[LDAPInetOrgPerson.propNameGivenName] = value.flatMap{ [Data($0.utf8)] } ?? []
					let sn = newLDAPObject.attributes[LDAPInetOrgPerson.propNameSN]?.first.flatMap{ String(data: $0, encoding: .utf8) }
					/* Updating cn (full name) */
					newLDAPObject.attributes[LDAPInetOrgPerson.propNameCN] = fullNameFrom(firstName: value, lastName: sn).flatMap{ [Data($0.utf8)] } ?? []
					
					res.insert(.firstName)
					res.insert(.custom("cn"))
					
				case .lastName:
					newLDAPObject.attributes[LDAPInetOrgPerson.propNameSN] = value.flatMap{ [Data($0.utf8)] } ?? []
					let gn = newLDAPObject.attributes[LDAPInetOrgPerson.propNameGivenName]?.first.flatMap{ String(data: $0, encoding: .utf8) }
					/* Updating cn (full name) */
					newLDAPObject.attributes[LDAPInetOrgPerson.propNameCN] = fullNameFrom(firstName: gn, lastName: value).flatMap{ [Data($0.utf8)] } ?? []
					
					res.insert(.lastName)
					res.insert(.custom("cn"))
					
				case .password:
					OfficeKitConfig.logger?.warning("Updating the password of an LDAP user might have unexpected consequences including security concerns. Please change the password of a user using the dedicated password change method.")
					newLDAPObject.attributes[LDAPInetOrgPerson.propNameUserPassword] = value.flatMap{ [Data($0.utf8)] } ?? []
					
				case .nickname, .custom:
					(/*nop (not supported)*/)
			}
		}
		
		guard let u = LDAPInetOrgPersonWithObject(object: newLDAPObject) else {
			OfficeKitConfig.logger?.warning("There was an unexpected error creating the inet org person from the LDAP object. Cannot apply hints.")
			return []
		}
		
		user = u
		return res
	}
	
	public func existingUser(fromPersistentId pId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> LDAPInetOrgPersonWithObject? {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> LDAPInetOrgPersonWithObject? {
		let eventLoop = try services.eventLoop()
		let ldapConnector: LDAPConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await ldapConnector.connect(scope: ())
		
		/* TODO: Implement properties to fetch. */
		let searchOp = SearchLDAPOperation(ldapConnector: ldapConnector, request: LDAPSearchRequest(scope: .base, base: uId, searchQuery: nil, attributesToFetch: nil))
		let searchResults = try await EventLoopFuture<[LDAPInetOrgPerson]>.future(from: searchOp, on: eventLoop).get()
		
		let c = searchResults.results.count
		guard let object = searchResults.results.first, c == 1 else {
			throw c == 0 ? Error.userNotFound : Error.tooManyUsersFound
		}
		guard let ret = LDAPInetOrgPersonWithObject(object: object) else {
			throw Error.internalError
		}
		return ret
	}
	
	public func listAllUsers(using services: Services) async throws -> [LDAPInetOrgPersonWithObject] {
		let eventLoop = try services.eventLoop()
		let ldapConnector: LDAPConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await ldapConnector.connect(scope: ())
		
		return try await withThrowingTaskGroup(of: [LDAPInetOrgPersonWithObject].self, returning: [LDAPInetOrgPersonWithObject].self, body: { group in
			for dn in config.baseDNs.allBaseDNs {
				group.addTask{
					let searchOp = SearchLDAPOperation(ldapConnector: ldapConnector, request: LDAPSearchRequest(scope: .children, base: dn, searchQuery: nil, attributesToFetch: nil))
					return try await EventLoopFuture<[LDAPInetOrgPerson]>.future(from: searchOp, on: eventLoop).get()
						.results
						.compactMap{ LDAPInetOrgPersonWithObject(object: $0) }
				}
			}
			
			var ret = [LDAPInetOrgPersonWithObject]()
			while let users = try await group.next() {
				ret += users
			}
			return ret
		})
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: LDAPInetOrgPersonWithObject, using services: Services) async throws -> LDAPInetOrgPersonWithObject {
		let eventLoop = try services.eventLoop()
		let ldapConnector: LDAPConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let op = CreateLDAPObjectsOperation(objects: [user.object], connector: ldapConnector)
		
		try await ldapConnector.connect(scope: ())
		
		let results = try await EventLoopFuture<[LDAPObject]>.future(from: op, on: eventLoop).get()
		guard let result = results.onlyElement else {
			throw InternalError(message: "Got no or more than one result from a CreateLDAPObjectsOperation that creates only one user.")
		}
		let object = try result.get()
		guard let person = LDAPInetOrgPerson(object: object) else {
			throw InternalError(message: "Cannot get an inet org person from the created object. The object may have been created on the LDAP.")
		}
		return LDAPInetOrgPersonWithObject(inetOrgPerson: person)
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: LDAPInetOrgPersonWithObject, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> LDAPInetOrgPersonWithObject {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: LDAPInetOrgPersonWithObject, using services: Services) async throws {
		let eventLoop = try services.eventLoop()
		let ldapConnector: LDAPConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let op = DeleteLDAPObjectsOperation(users: [user.inetOrgPerson], connector: ldapConnector)
		
		try await ldapConnector.connect(scope: ())
		
		return try await EventLoopFuture<Void>.future(from: op, on: eventLoop, resultRetriever: { if let e = $0.errors[0] {throw e} }).get()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: LDAPInetOrgPersonWithObject, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user.userId, additionalInitInfo: ldapConnector) as ResetLDAPPasswordAction
	}
	
	public func authenticate(userId dn: LDAPDistinguishedName, challenge checkedPassword: String, using services: Services) async throws -> Bool {
		guard !checkedPassword.isEmpty else {throw Error.passwordIsEmpty}
		
		var ldapConnectorConfig = self.config.connectorSettings
		ldapConnectorConfig.authMode = .userPass(username: dn.stringValue, password: checkedPassword)
		let connector = try LDAPConnector(key: ldapConnectorConfig)
		
		do {
			try await connector.connect(scope: (), forceReconnect: true)
		} catch let error where LDAPConnector.isInvalidPassError(error) {
			return false
		}
		return true
	}
	
	public func validateAdminStatus(userId: LDAPDistinguishedName, using services: Services) async throws -> Bool {
		let eventLoop = try services.eventLoop()
		
		let adminGroupsDN = config.adminGroupsDN
		guard adminGroupsDN.count > 0 else {return false}
		
		let ldapConnector: LDAPConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let searchQuery = LDAPSearchQuery.or(adminGroupsDN.map{
			LDAPSearchQuery.simple(attribute: .memberof, filtertype: .equal, value: Data($0.stringValue.utf8))
		})
		
		try await ldapConnector.connect(scope: ())
		
		let op = SearchLDAPOperation(ldapConnector: ldapConnector, request: LDAPSearchRequest(scope: .subtree, base: userId, searchQuery: searchQuery, attributesToFetch: nil))
		let objects = try await EventLoopFuture<[LDAPInetOrgPerson]>.future(from: op, on: eventLoop).get().results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) }
		guard objects.count <= 1 else {
			throw Error.tooManyUsersFound
		}
		guard let inetOrgPerson = objects.first else {
			return false
		}
		return inetOrgPerson.userId == userId
	}
	
	public func fetchProperties(_ properties: Set<String>?, from dn: LDAPDistinguishedName, using services: Services) async throws -> [String: [Data]] {
		let eventLoop = try services.eventLoop()
		let ldapConnector: LDAPConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let searchRequest = LDAPSearchRequest(scope: .base, base: dn, searchQuery: nil, attributesToFetch: properties)
		let op = SearchLDAPOperation(ldapConnector: ldapConnector, request: searchRequest)
		
		try await ldapConnector.connect(scope: ())
		
		let ldapObjects = try await EventLoopFuture<[LDAPInetOrgPerson]>.future(from: op, on: eventLoop).get().results
		guard ldapObjects.count <= 1             else {throw Error.tooManyUsersFound}
		guard let ldapObject = ldapObjects.first else {throw Error.userNotFound}
		return ldapObject.attributes
	}
	
	public func fetchUniqueEmails(from user: LDAPInetOrgPersonWithObject, deduplicateAliases: Bool = true, using services: Services) async throws -> Set<Email> {
		let properties = try await fetchProperties([LDAPInetOrgPerson.propNameMail], from: user.userId, using: services)
		guard let emailDataArray = properties[LDAPInetOrgPerson.propNameMail] else {
			throw Error.internalError
		}
		let emails = try emailDataArray.map{ emailData -> Email in
			guard let emailStr = String(data: emailData, encoding: .utf8), let email = Email(rawValue: emailStr) else {
				throw Error.invalidEmailInLDAP
			}
			return email
		}
		/* Deduplication */
		if !deduplicateAliases {return Set(emails)}
		return Set(emails.map{ $0.primaryDomainVariant(aliasMap: self.globalConfig.domainAliases) })
	}
	
}
