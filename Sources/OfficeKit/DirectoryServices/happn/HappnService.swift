/*
 * HappnService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/28.
 */

import Foundation

import Email
import GenericJSON
import NIO
import OperationAwaiting
import SemiSingleton
import ServiceKit



/**
 A happn service.
 
 Dependencies:
 - Event-loop,
 - Semi-singleton store. */
public final class HappnService : UserDirectoryService {
	
	public static var providerID = "internal_happn"
	
	public typealias ConfigType = HappnServiceConfig
	public typealias UserType = HappnUser
	
	public let config: HappnServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: HappnUser) -> String {
		return user.login ?? "<null user id>"
	}
	
	public func string(fromUserID userID: String?) -> String {
		return userID ?? "__officectl_internal__null_happn_id__"
	}
	
	public func userID(fromString string: String) throws -> String? {
		guard string != "__officectl_internal__null_happn_id__" else {
			return nil
		}
		return string
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: HappnUser) throws -> JSON {
		/* Probably not optimal in terms of speed, but works well and avoids having a shit-ton of glue to create in the HappnUser (or in this method). */
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> HappnUser {
		/* Probably not optimal in terms of speed, but works well and avoids having a shit-ton of glue to create in the HappnUser (or in this method). */
		let encoded = try JSONEncoder().encode(json)
		return try JSONDecoder().decode(HappnUser.self, from: encoded)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> HappnUser {
		if userWrapper.sourceServiceID == config.serviceID, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserID: String?
		if userWrapper.sourceServiceID == config.serviceID {
			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
			inferredUserID = userWrapper.userID.id
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create a HappnUser")
			}
			inferredUserID = email.rawValue
		}
		
		var res = HappnUser(login: inferredUserID)
		if userWrapper.remoteFirstName != .unsupported {res.firstName = userWrapper.firstName ?? ""}
		if userWrapper.remoteLastName  != .unsupported {res.lastName  = userWrapper.lastName ?? ""}
		if userWrapper.remoteNickname  != .unsupported {res.nickname  = userWrapper.nickname ?? ""}
		return res
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout HappnUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		var res = Set<DirectoryUserProperty>()
		/* For all changes below we nullify the record because changing the record is not something that is possible and
		 * we want the record wrapper and its underlying record to be in sync.
		 * So all changes to the wrapper must be done with a nullification of the underlying record. */
		for (property, value) in hints {
			switch property {
				case .userID:
					guard allowUserIDChange else {continue}
					user.login = value
					res.insert(.identifyingEmail)
					res.insert(.userID)
					
				case .identifyingEmail:
					guard allowUserIDChange else {continue}
					guard hints[.userID] == nil else {
						if hints[.userID] != value {
							OfficeKitConfig.logger?.warning("Invalid hints given for a HappnUser: both userID and identifyingEmail are defined with different values. Only userID will be used.")
						}
						continue
					}
					guard let email = value.flatMap({ Email(rawValue: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid value for an identifying email of a happn user.")
						continue
					}
					user.login = email.rawValue
					res.insert(.identifyingEmail)
					res.insert(.userID)
					
				case .persistentID:
					guard let id = value else {
						OfficeKitConfig.logger?.warning("Invalid value for a persistent ID of a happn user.")
						continue
					}
					user.id = id
					res.insert(.persistentID)
					
				case .firstName:
					user.firstName = value ?? ""
					res.insert(.firstName)
					
				case .lastName:
					user.lastName = value ?? ""
					res.insert(.lastName)
					
				case .nickname:
					user.nickname = value ?? ""
					res.insert(.nickname)
					
				case .password:
					guard let pass = value else {
						OfficeKitConfig.logger?.warning("The password of a happn user cannot be removed.")
						continue
					}
					OfficeKitConfig.logger?.warning("Setting the password of a happn user via hints can lead to unexpected results (including security flaws for this user). Please use the dedicated method to set the password in the service.")
					user.password = pass
					res.insert(.password)
					
				case .custom("gender"):
					guard let gender = value.flatMap({ HappnUser.Gender(rawValue: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid gender for a happn user.")
						continue
					}
					user.gender = gender
					
				case .custom("birthdate"):
					guard let birthdate = value.flatMap({ HappnUser.birthDateFormatter.date(from: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid gender for a happn user.")
						continue
					}
					user.birthDate = birthdate
					
				case .otherEmails, .custom:
					(/*nop (not supported)*/)
			}
		}
		return res
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> HappnUser? {
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await happnConnector.connect(scope: GetHappnUserOperation.scopes)
		
		/* TODO: Properties to fetch. */
		let op = GetHappnUserOperation(userKey: pID, connector: happnConnector)
		do {
			return try await services.opQ.addOperationAndGetResult(op)
		} catch let error as NSError where error.domain == "com.happn.officectl.happn" && error.code == 25002 {
			return nil
		}
	}
	
	public func existingUser(fromUserID uID: String?, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> HappnUser? {
		guard let uID = uID else {
			/* Yes.
			 * It’s ugly.
			 * But the only admin user with a nil login is 244. */
			return try await existingUser(fromPersistentID: HappnConnector.nullLoginUserID, propertiesToFetch: propertiesToFetch, using: services)
		}
		
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await happnConnector.connect(scope: SearchHappnUsersOperation.scopes)
		
		let ids = Set(Email(rawValue: uID)?.allDomainVariants(aliasMap: self.globalConfig.domainAliases).map{ $0.rawValue } ?? [uID])
		let ops = ids.map{ SearchHappnUsersOperation(email: $0, happnConnector: happnConnector) } /* TODO: Properties to fetch. */
		let users = try await services.opQ.addOperationsAndGetResults(ops).map{ try $0.get() }.flatMap{ $0 }
		guard users.count <= 1 else {
			throw InvalidArgumentError(message: "Given user ID has more than one user found")
		}
		return users.first
	}
	
	public func listAllUsers(using services: Services) async throws -> [HappnUser] {
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await happnConnector.connect(scope: SearchHappnUsersOperation.scopes)
		
		let searchOp = SearchHappnUsersOperation(email: nil, happnConnector: happnConnector)
		return try await services.opQ.addOperationAndGetResult(searchOp)
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: HappnUser, using services: Services) async throws -> HappnUser {
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await happnConnector.connect(scope: CreateHappnUserOperation.scopes)
		
		var user = user
		if user.password == nil {
			/* Creating a user without a password is not possible.
			 * Let’s generate a password!
			 * A long and complex one. */
			OfficeKitConfig.logger?.warning("Auto-generating a random password for happn user creation: creating a happn user w/o a password is not supported.")
			let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=+_-$!@#%^&*(){}[]'\\\";:/?.>,<§"
			user.password = String((0..<64).map{ _ in chars.randomElement()! })
		}
		
		let op = CreateHappnUserOperation(user: user, connector: happnConnector)
		return try await services.opQ.addOperationAndGetResult(op)
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: HappnUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> HappnUser {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: HappnUser, using services: Services) async throws {
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await happnConnector.connect(scope: DeleteHappnUserOperation.scopes)
		
		let op = DeleteHappnUserOperation(user: user, connector: happnConnector)
		return try await services.opQ.addOperationAndGetResult(op)
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: HappnUser, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		let happnConnector: HappnConnector = semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: happnConnector) as ResetHappnPasswordAction
	}
	
}
