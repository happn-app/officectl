/*
 * OpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

#if !canImport(DirectoryService) || !canImport(OpenDirectory)

public typealias OpenDirectoryService = DummyService

#else

import Foundation
import OpenDirectory

import Async
import GenericJSON
import SemiSingleton
import Service



public final class OpenDirectoryService : DirectoryService {
	
	public static let providerId = "internal_opendirectory"
	
	public enum ODError : Error {
		
		case uidMissingInDN
		case tooManyUsersFound
		case noRecordInRecordWrapper
		case unsupportedServiceUserIdConversion
		
	}
	
	public typealias ConfigType = OpenDirectoryServiceConfig
	public typealias UserIdType = ODRecordOKWrapper
	public typealias AuthenticationChallenge = String
	
	public let config: OpenDirectoryServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(from user: ODRecordOKWrapper) -> String {
		return user.userId.stringValue
	}
	
	public func string(fromUserId userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentId pId: UUID) -> String {
		return pId.uuidString
	}
	
	public func persistentId(fromString string: String) throws -> UUID {
		guard let uuid = UUID(uuidString: string) else {
			throw InvalidArgumentError(message: "Invalid persistent id \(string)")
		}
		return uuid
	}
	
	public func json(fromUser user: ODRecordOKWrapper) throws -> JSON {
		var ret = ["dn": JSON.string(user.userId.stringValue)]
		if let record = user.record {
			/* Is this making IO? Who knows… But it shouldn’t be; doc says if
			 * attributes is nil the method returns what’s in the cache. */
			let attributes = try record.recordDetails(forAttributes: nil)
			for (key, val) in attributes {
				guard let keyStr = key as? String else {
					OfficeKitConfig.logger?.warning("Skipping conversion of a key in an OpenDirectory Object because it’s not a string: \(key)")
					continue
				}
				guard keyStr != "dn" else {continue}
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
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> ODRecordOKWrapper {
		let taggedId = userWrapper.userId
		if taggedId.tag == config.serviceId/*, let underlying = userWrapper.underlyingUser*/ {
			/* The generic user is from our service! We should be able to translate
			 * if fully to our User type. */
			guard let dn = try? LDAPDistinguishedName(string: taggedId.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but which does not have a valid dn.")
			}
			#warning("TODO: The rest of the properties (from the underlying user).")
			return ODRecordOKWrapper(id: dn, identifyingEmail: nil, otherEmails: [])
			
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create an ODRecordOKWrapper")
			}
			guard let dn = config.baseDNs.dn(fromEmail: email) else {
				throw InvalidArgumentError(message: "Cannot get dn from \(email).")
			}
			#warning("TODO: The rest of the properties.")
			return ODRecordOKWrapper(id: dn, identifyingEmail: email, otherEmails: [])
		}
	}
	
	public func existingUser(fromPersistentId pId: UUID, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId dn: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		/* Note: I’d very much like to search the whole DN instead of the UID
		 *       only, but I was not able to make it work. */
		guard let uid = dn.uid else {throw ODError.uidMissingInDN}
		let request = OpenDirectorySearchRequest(uid: uid)
		return try existingRecord(fromSearchRequest: request, on: container)
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[ODRecordOKWrapper]> {
		let openDirectoryConnector: OpenDirectoryConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let searchQuery = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeMetaRecordName, matchType: ODMatchType(kODMatchAny), queryValues: nil, returnAttributes: [kODAttributeTypeEMailAddress, kODAttributeTypeFullName], maximumResults: nil)
		let op = SearchOpenDirectoryOperation(request: searchQuery, openDirectoryConnector: openDirectoryConnector)
		return openDirectoryConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ Future<[ODRecord]>.future(from: op, eventLoop: container.eventLoop).map{ $0.compactMap{ try? ODRecordOKWrapper(record: $0) } } }
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: ODRecordOKWrapper, on container: Container) throws -> Future<ODRecordOKWrapper> {
		let openDirectoryConnector: OpenDirectoryConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let op = try CreateOpenDirectoryRecordOperation(user: user, connector: openDirectoryConnector)
		return openDirectoryConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ in Future<ODRecordOKWrapper>.future(from: op, eventLoop: container.eventLoop).map{ try ODRecordOKWrapper(record: $0) } }
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: ODRecordOKWrapper, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: ODRecordOKWrapper, on container: Container) throws -> Future<Void> {
		return try self.existingUser(fromUserId: user.userId, propertiesToFetch: [], on: container)
		.flatMap{ u in
			#warning("TODO: Error is not correct")
			guard let r = u?.record else {throw ODError.noRecordInRecordWrapper}
			return Future<Void>.future(from: DeleteOpenDirectoryRecordOperation(record: r), eventLoop: container.eventLoop)
		}
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: ODRecordOKWrapper, on container: Container) throws -> ResetPasswordAction {
		let semiSingletonStore: SemiSingletonStore = try container.make()
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user.userId, additionalInitInfo: openDirectoryConnector) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func existingRecord(fromSearchRequest request: OpenDirectorySearchRequest, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		var request = request
		request.maximumResults = 2
		
		let openDirectoryConnector: OpenDirectoryConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		let future = openDirectoryConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ -> Future<[ODRecord]> in
			let op = SearchOpenDirectoryOperation(request: request, openDirectoryConnector: openDirectoryConnector)
			return Future<[ODRecord]>.future(from: op, eventLoop: container.eventLoop)
		}
		.thenThrowing{ objects -> ODRecordOKWrapper? in
			guard objects.count <= 1 else {
				throw ODError.tooManyUsersFound
			}
			return try objects.first.flatMap{ try ODRecordOKWrapper(record: $0) }
		}
		return future
	}
	
}

#endif
