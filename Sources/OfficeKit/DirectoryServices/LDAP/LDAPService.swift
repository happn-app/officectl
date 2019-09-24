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
	
	public func shortDescription(from user: LDAPInetOrgPersonWithObject) -> String {
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
		if userWrapper.sourceServiceId == config.serviceId {
			if let underlyingUser = userWrapper.underlyingUser {return try logicalUser(fromJSON: underlyingUser)}
			else {
				guard let dn = try? LDAPDistinguishedName(string: userWrapper.userId.id) else {
					throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but which does not have a valid dn.")
				}
				return LDAPInetOrgPersonWithObject(inetOrgPerson: LDAPInetOrgPerson(dn: dn, sn: [], cn: []))
			}
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
			throw InvalidArgumentError(message: "Cannot get an email from the user to create an LDAPInetOrgPersonWithObject")
		}
		guard let dn = config.baseDNs.dn(fromEmail: email) else {
			throw InvalidArgumentError(message: "Cannot get dn from \(email).")
		}
		let lastName = userWrapper.lastName.value?.flatMap{ $0 }
		let firstName = userWrapper.firstName.value?.flatMap{ $0 }
		let fullname = fullNameFrom(firstName: firstName, lastName: lastName)
		let ret = LDAPInetOrgPersonWithObject(inetOrgPerson: LDAPInetOrgPerson(dn: dn, sn: lastName.flatMap{ [$0] } ?? [], cn: fullname.flatMap{ [$0] } ?? []))
		ret.inetOrgPerson.givenName = firstName.flatMap{ [$0] } ?? []
		ret.inetOrgPerson.mail = userWrapper.emails
		return ret
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
				guard let email = Email(string: emailStr) else {
					OfficeKitConfig.logger?.warning("Invalid value for an identifying email; not applying this hint nor otherEmails: \(value ?? "<null>")")
					continue
				}
				/* Yes. We cannot represent an element in the list which contains a
				 * comma. Maybe one day we’ll do the generic thing… */
				let otherEmails: [Email]
				let otherEmailsStrArray = hints[.otherEmails]??.split(separator: ",")
				if let emails = try? otherEmailsStrArray?.map({ try nil2throw(Email(string: String($0))) }) {
					otherEmails = emails
					res.insert(.otherEmails)
				} else {
					otherEmails = []
				}
				res.insert(.identifyingEmail)
				newLDAPObject.attributes[LDAPInetOrgPerson.propNameMail] = [Data(email.stringValue.utf8)] + otherEmails.map{ Data($0.stringValue.utf8) }
				
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
			return Set(emails.map{ $0.primaryDomainVariant(aliasMap: self.globalConfig.domainAliases) })
		}
	}
	
}
