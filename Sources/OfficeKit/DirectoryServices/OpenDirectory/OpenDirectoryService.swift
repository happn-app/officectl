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

import AsyncKit
import GenericJSON
import NIO
import SemiSingleton
import Vapor



public final class OpenDirectoryService : UserDirectoryService {
	
	public static let providerId = "internal_opendirectory"
	
	public enum ODError : Error {
		
		case uidMissingInDN
		case tooManyUsersFound
		case noRecordInRecordWrapper
		case unsupportedServiceUserIdConversion
		
	}
	
	public typealias ConfigType = OpenDirectoryServiceConfig
	public typealias IdType = ODRecordOKWrapper
	public typealias AuthenticationChallenge = String
	
	public let config: OpenDirectoryServiceConfig
	public let globalConfig: GlobalConfig
	
	/* Required services */
	public let semiSingletonStore: SemiSingletonStore
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig, application: Application) {
		config = c
		globalConfig = gc
		semiSingletonStore = application.make()
	}
	
	public func shortDescription(fromUser user: ODRecordOKWrapper) -> String {
		return user.userId.stringValue
	}
	
	public func string(fromUserId userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentUserId pId: UUID) -> String {
		return pId.uuidString
	}
	
	public func persistentUserId(fromString string: String) throws -> UUID {
		guard let uuid = UUID(uuidString: string) else {
			throw InvalidArgumentError(message: "Invalid persistent id \(string)")
		}
		return uuid
	}
	
	public func json(fromUser user: ODRecordOKWrapper) throws -> JSON {
		var ret: [String: JSON] = [:]
		if let record = user.record {
			/* Is this making IO? Who knows… But it shouldn’t be; doc says if
			 * attributes is nil the method returns what’s in the cache. */
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
		if userWrapper.sourceServiceId == config.serviceId {
			if let underlyingUser = userWrapper.underlyingUser {return try logicalUser(fromJSON: underlyingUser)}
			else {
				guard let dn = try? LDAPDistinguishedName(string: userWrapper.userId.id) else {
					throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but which does not have a valid dn.")
				}
				return ODRecordOKWrapper(id: dn, identifyingEmail: nil, otherEmails: [])
			}
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
			throw InvalidArgumentError(message: "Cannot get an email from the user to create an ODRecordOKWrapper")
		}
		guard let dn = config.baseDNs.dn(fromEmail: email) else {
			throw InvalidArgumentError(message: "Cannot get dn from \(email).")
		}
		let lastName = userWrapper.lastName.value?.flatMap{ $0 }
		let firstName = userWrapper.firstName.value?.flatMap{ $0 }
		return ODRecordOKWrapper(id: dn, identifyingEmail: email, otherEmails: Array(userWrapper.emails.dropFirst()), firstName: firstName, lastName: lastName)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout ODRecordOKWrapper, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		var res = Set<DirectoryUserProperty>()
		/* For all changes below we nullify the record because changing the record
		 * is not something that is possible and we want the record wrapper and
		 * its underlying record to be in sync. So all changes to the wrapper must
		 * be done with a nullification of the underlying record. */
		for (property, value) in hints {
			switch property {
			case .userId:
				guard allowUserIdChange else {continue}
				guard let dn = value.flatMap({ try? LDAPDistinguishedName(string: $0) }) else {
					OfficeKitConfig.logger?.warning("Invalid value for the user id of an OD user; not applying hint: \(value ?? "<null>")")
					continue
				}
				user.record = nil
				user.userId = dn
				res.insert(.userId)
				
			case .persistentId:
				guard let uuid = value.flatMap({ UUID(uuidString: $0) }) else {
					OfficeKitConfig.logger?.warning("Invalid value for the persistent id of an OD user; not applying hint: \(value ?? "<null>")")
					continue
				}
				user.record = nil
				user.persistentId = .set(uuid)
				res.insert(.persistentId)
				
			case .identifyingEmail:
				guard let emailStr = value else {
					user.record = nil
					user.identifyingEmail = .set(nil)
					res.insert(.identifyingEmail)
					continue
				}
				guard let email = Email(string: emailStr) else {
					OfficeKitConfig.logger?.warning("Invalid value for the identifying email of an OD user; not applying hint: \(value ?? "<null>")")
					continue
				}
				user.record = nil
				user.identifyingEmail = .set(email)
				res.insert(.identifyingEmail)
				
			case .otherEmails:
				guard let emailsStr = value else {
					user.record = nil
					user.otherEmails = .set([])
					res.insert(.otherEmails)
					continue
				}
				/* Yes. We cannot represent an element in the list which contains a
				 * comma. Maybe one day we’ll do the generic thing… */
				let emailsArrayStr = emailsStr.split(separator: ",")
				guard let emails = try? emailsArrayStr.map({ try nil2throw(Email(string: String($0))) }) else {
					OfficeKitConfig.logger?.warning("Invalid value for the other emails of an OD user; not applying hint: \(value ?? "<null>")")
					continue
				}
				user.record = nil
				user.otherEmails = .set(emails)
				res.insert(.otherEmails)
				
			case .firstName:
				user.record = nil
				user.firstName = .set(value)
				res.insert(.firstName)
				
			case .lastName:
				user.record = nil
				user.lastName = .set(value)
				res.insert(.lastName)
				
			case .password:
				OfficeKitConfig.logger?.warning("Cannot set password of an OD user by applying hints. Please use the dedicated method to change password in the service.")
				
			case .nickname, .custom:
				(/*nop (not supported)*/)
			}
		}
		return res
	}
	
	public func existingUser(fromPersistentId pId: UUID, propertiesToFetch: Set<DirectoryUserProperty>, on eventLoop: EventLoop) throws -> EventLoopFuture<ODRecordOKWrapper?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId dn: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on eventLoop: EventLoop) throws -> EventLoopFuture<ODRecordOKWrapper?> {
		/* Note: I’d very much like to search the whole DN instead of the UID
		 *       only, but I was not able to make it work. */
		guard let uid = dn.uid else {throw ODError.uidMissingInDN}
		let request = OpenDirectorySearchRequest(uid: uid)
		return try existingRecord(fromSearchRequest: request, on: eventLoop)
	}
	
	public func listAllUsers(on eventLoop: EventLoop) throws -> EventLoopFuture<[ODRecordOKWrapper]> {
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		
		let searchQuery = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeMetaRecordName, matchType: ODMatchType(kODMatchAny), queryValues: nil, returnAttributes: [kODAttributeTypeEMailAddress, kODAttributeTypeFullName], maximumResults: nil)
		let op = SearchOpenDirectoryOperation(request: searchQuery, openDirectoryConnector: openDirectoryConnector)
		return openDirectoryConnector.connect(scope: (), eventLoop: eventLoop)
		.flatMap{ EventLoopFuture<[ODRecord]>.future(from: op, on: eventLoop).map{ $0.compactMap{ try? ODRecordOKWrapper(record: $0) } } }
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: ODRecordOKWrapper, on eventLoop: EventLoop) throws -> EventLoopFuture<ODRecordOKWrapper> {
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		
		let op = try CreateOpenDirectoryRecordOperation(user: user, connector: openDirectoryConnector)
		return openDirectoryConnector.connect(scope: (), eventLoop: eventLoop)
		.flatMap{ _ in EventLoopFuture<ODRecordOKWrapper>.future(from: op, on: eventLoop).flatMapThrowing{ try ODRecordOKWrapper(record: $0) } }
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: ODRecordOKWrapper, propertiesToUpdate: Set<DirectoryUserProperty>, on eventLoop: EventLoop) throws -> EventLoopFuture<ODRecordOKWrapper> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: ODRecordOKWrapper, on eventLoop: EventLoop) throws -> EventLoopFuture<Void> {
		return try self.existingUser(fromUserId: user.userId, propertiesToFetch: [], on: eventLoop)
		.flatMapThrowing{ u in
			#warning("TODO: Error is not correct")
			guard let r = u?.record else {throw ODError.noRecordInRecordWrapper}
			return r
		}
		.flatMap{ r in
			return EventLoopFuture<Void>.future(from: DeleteOpenDirectoryRecordOperation(record: r), on: eventLoop)
		}
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: ODRecordOKWrapper, on eventLoop: EventLoop) throws -> ResetPasswordAction {
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user.userId, additionalInitInfo: openDirectoryConnector) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func existingRecord(fromSearchRequest request: OpenDirectorySearchRequest, on eventLoop: EventLoop) throws -> EventLoopFuture<ODRecordOKWrapper?> {
		var request = request
		request.maximumResults = 2
		
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		let future = openDirectoryConnector.connect(scope: (), eventLoop: eventLoop)
		.flatMap{ _ -> EventLoopFuture<[ODRecord]> in
			let op = SearchOpenDirectoryOperation(request: request, openDirectoryConnector: openDirectoryConnector)
			return EventLoopFuture<[ODRecord]>.future(from: op, on: eventLoop)
		}
		.flatMapThrowing{ objects -> ODRecordOKWrapper? in
			guard objects.count <= 1 else {
				throw ODError.tooManyUsersFound
			}
			return try objects.first.flatMap{ try ODRecordOKWrapper(record: $0) }
		}
		return future
	}
	
}

#endif
