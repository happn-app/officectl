/*
 * OpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/20.
 */

#if !canImport(DirectoryService) || !canImport(OpenDirectory)

public typealias OpenDirectoryService = DummyService

#else

import Foundation
import OpenDirectory

import Email
import GenericJSON
import NIO
import SemiSingleton
import UnwrapOrThrow

import ServiceKit



/**
 An Open-Directory service (only available on macOS).
 
 Dependencies:
 - Event-loop
 - Semi-singleton store. */
public final class OpenDirectoryService : UserDirectoryService {
	
	public static let providerID = "internal_opendirectory"
	
	public enum ODError : Error {
		
		case uidMissingInDN
		case tooManyUsersFound
		case noRecordInRecordWrapper
		case unsupportedServiceUserIDConversion
		
	}
	
	public typealias ConfigType = OpenDirectoryServiceConfig
	public typealias IDType = ODRecordOKWrapper
	public typealias AuthenticationChallenge = String
	
	public let config: OpenDirectoryServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
		
		serialQueueForUserCreationOperation = OperationQueue(name_OperationQueue: "Operation Queue for OD User Creations")
		serialQueueForUserCreationOperation.maxConcurrentOperationCount = 1
	}
	
	public func shortDescription(fromUser user: ODRecordOKWrapper) -> String {
		return user.userID.stringValue
	}
	
	public func string(fromUserID userID: LDAPDistinguishedName) -> String {
		return userID.stringValue
	}
	
	public func userID(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentUserID pID: UUID) -> String {
		return pID.uuidString
	}
	
	public func persistentUserID(fromString string: String) throws -> UUID {
		guard let uuid = UUID(uuidString: string) else {
			throw InvalidArgumentError(message: "Invalid persistent ID \(string)")
		}
		return uuid
	}
	
	public func json(fromUser user: ODRecordOKWrapper) throws -> JSON {
		var ret: [String: JSON] = [:]
		if let record = user.record {
			/* Is this making IO?
			 * Who knows…
			 * But it shouldn’t be; doc says if attributes is nil the method returns what’s in the cache. */
			let attributes = try record.recordDetails(forAttributes: nil)
			for (key, val) in attributes {
				guard let keyStr = key as? String else {
					OfficeKitConfig.logger?.warning("Skipping conversion of a key in an OpenDirectory Object because it’s not a string: \(key)")
					continue
				}
				switch val {
					case let str       as  String:  ret[keyStr] =                          JSON.object(["str": JSON.string(str)])
					case let strArray  as [String]: ret[keyStr] = JSON.array(strArray.map{ JSON.object(["str": JSON.string($0)]) })
					case let data      as  Data:    ret[keyStr] =                           JSON.object(["dta": JSON.string(data.base64EncodedString())])
					case let dataArray as [Data]:   ret[keyStr] = JSON.array(dataArray.map{ JSON.object(["dta": JSON.string($0.base64EncodedString())]) })
					default:
						OfficeKitConfig.logger?.warning("Skipping conversion of a key \(keyStr) in an OpenDirectory Object because the value is not of a known type: \(val)")
						continue
				}
			}
		}
		return .object(ret)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> ODRecordOKWrapper {
		guard let object = json.objectValue else {
			throw InvalidArgumentError(message: "Invalid json: not an object.")
		}
		let ldapObjectAttributes = try object.filter{ $0.key != "dn" }.mapValues{ value -> [Any] in
			guard case .array(let array) = value else {throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value is not an array")}
			return try array.map{ arrayValue in
				guard case .object(let object) = arrayValue else {throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value has a non-object element")}
				guard object.count == 1 else {throw InvalidArgumentError(message: "Invalid value in JSON for an LDAP user: attribute value has an object containing more than one element")}
				if let strValue = object["str"]?.stringValue {
					return strValue
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
		return try ODRecordOKWrapper(recordAttributes: ldapObjectAttributes)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> ODRecordOKWrapper {
		if userWrapper.sourceServiceID == config.serviceID, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserID: LDAPDistinguishedName
		if userWrapper.sourceServiceID == config.serviceID {
			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
			guard let dn = try? LDAPDistinguishedName(string: userWrapper.userID.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose ID comes from our service, but which does not have a valid dn.")
			}
			inferredUserID = dn
		} else {
			/* The given user comes from another service.
			 * Let’s try and infer an ID from this user, using its email. */
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create an ODRecordOKWrapper")
			}
			guard let dn = config.baseDNs.dn(fromEmail: email) else {
				throw InvalidArgumentError(message: "Cannot get dn from \(email).")
			}
			inferredUserID = dn
		}
		
		let lastName = userWrapper.lastName ?? nil
		let firstName = userWrapper.firstName ?? nil
		return ODRecordOKWrapper(id: inferredUserID, identifyingEmail: userWrapper.identifyingEmail ?? nil, otherEmails: userWrapper.otherEmails ?? [], firstName: firstName, lastName: lastName)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout ODRecordOKWrapper, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		var res = Set<DirectoryUserProperty>()
		/* For all changes below we nullify the record because changing the record is not something that is possible and
		 * we want the record wrapper and its underlying record to be in sync.
		 * So all changes to the wrapper must be done with a nullification of the underlying record. */
		for (property, value) in hints {
			switch property {
				case .userID:
					guard allowUserIDChange else {continue}
					guard let dn = value.flatMap({ try? LDAPDistinguishedName(string: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid value for the user ID of an OD user; not applying hint: \(value ?? "<null>")")
						continue
					}
					user.record = nil
					user.userID = dn
					res.insert(.userID)
					
				case .persistentID:
					guard let uuid = value.flatMap({ UUID(uuidString: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid value for the persistent ID of an OD user; not applying hint: \(value ?? "<null>")")
						continue
					}
					user.record = nil
					user.persistentID = uuid
					res.insert(.persistentID)
					
				case .identifyingEmail:
					guard let emailStr = value else {
						user.record = nil
						user.identifyingEmail = .some(nil)
						res.insert(.identifyingEmail)
						continue
					}
					guard let email = Email(rawValue: emailStr) else {
						OfficeKitConfig.logger?.warning("Invalid value for the identifying email of an OD user; not applying hint: \(value ?? "<null>")")
						continue
					}
					user.record = nil
					user.identifyingEmail = email
					res.insert(.identifyingEmail)
					
				case .otherEmails:
					guard let emailsStr = value else {
						user.record = nil
						user.otherEmails = []
						res.insert(.otherEmails)
						continue
					}
					/* Yes.
					 * We cannot represent an element in the list which contains a comma.
					 * Maybe one day we’ll do the generic thing… */
					let emailsArrayStr = emailsStr.split(separator: ",")
					guard let emails = try? emailsArrayStr.map({ try Email(rawValue: String($0)) ?! Err.genericError("Invalid email \($0)") }) else {
						OfficeKitConfig.logger?.warning("Invalid value for the other emails of an OD user; not applying hint: \(value ?? "<null>")")
						continue
					}
					user.record = nil
					user.otherEmails = emails
					res.insert(.otherEmails)
					
				case .firstName:
					user.record = nil
					user.firstName = value
					res.insert(.firstName)
					
				case .lastName:
					user.record = nil
					user.lastName = value
					res.insert(.lastName)
					
				case .password:
					OfficeKitConfig.logger?.warning("Cannot set password of an OD user by applying hints. Please use the dedicated method to change password in the service.")
					
				case .nickname, .custom:
					(/*nop (not supported)*/)
			}
		}
		return res
	}
	
	public func existingUser(fromPersistentID pID: UUID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> ODRecordOKWrapper? {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserID dn: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> ODRecordOKWrapper? {
		/* Note: I’d very much like to search the whole DN instead of the UID only, but I was not able to make it work. */
		guard let uid = dn.uid else {throw ODError.uidMissingInDN}
		let request = OpenDirectorySearchRequest(uid: uid)
		return try await existingRecord(fromSearchRequest: request, using: services)
	}
	
	public func listAllUsers(using services: Services) async throws -> [ODRecordOKWrapper] {
		let openDirectoryConnector: OpenDirectoryConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await openDirectoryConnector.connect(scope: ())
		
		let searchQuery = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeMetaRecordName, matchType: ODMatchType(kODMatchAny), queryValues: nil, returnAttributes: [kODAttributeTypeEMailAddress, kODAttributeTypeFullName], maximumResults: nil)
		let op = SearchOpenDirectoryOperation(request: searchQuery, openDirectoryConnector: openDirectoryConnector)
		return try await services.opQ.addOperationAndGetResult(op).compactMap{ try? ODRecordOKWrapper(record: $0) }
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: ODRecordOKWrapper, using services: Services) async throws -> ODRecordOKWrapper {
		let openDirectoryConnector: OpenDirectoryConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await openDirectoryConnector.connect(scope: ())
		
		let op = try CreateOpenDirectoryRecordOperation(user: user, connector: openDirectoryConnector)
		return try await ODRecordOKWrapper(record: services.opQ.addOperationAndGetResult(op))
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: ODRecordOKWrapper, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> ODRecordOKWrapper {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: ODRecordOKWrapper, using services: Services) async throws {
		let u = try await self.existingUser(fromUserID: user.userID, propertiesToFetch: [], using: services)
		guard let r = u?.record else {
			/* TODO: Error is not correct. */
			throw ODError.noRecordInRecordWrapper
		}
		
		return try await services.opQ.addOperationAndGetResult(DeleteOpenDirectoryRecordOperation(record: r))
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: ODRecordOKWrapper, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user.userID, additionalInitInfo: openDirectoryConnector) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let serialQueueForUserCreationOperation: OperationQueue
	
	private func existingRecord(fromSearchRequest request: OpenDirectorySearchRequest, using services: Services) async throws -> ODRecordOKWrapper? {
		var request = request
		request.maximumResults = 2
		
		let openDirectoryConnector: OpenDirectoryConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await openDirectoryConnector.connect(scope: ())
		
		let op = SearchOpenDirectoryOperation(request: request, openDirectoryConnector: openDirectoryConnector)
		let objects = try await services.opQ.addOperationAndGetResult(op)
		guard objects.count <= 1 else {
			throw ODError.tooManyUsersFound
		}
		return try objects.first.flatMap{ try ODRecordOKWrapper(record: $0) }
	}
	
}

#endif
