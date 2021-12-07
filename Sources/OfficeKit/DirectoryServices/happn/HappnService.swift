/*
 * HappnService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/08/2019.
 */

import Foundation

import Email
import GenericJSON
import NIO
import SemiSingleton
import ServiceKit



/**
 A happn service.
 
 Dependencies:
 - Event-loop,
 - Semi-singleton store. */
public final class HappnService : UserDirectoryService {
	
	public static var providerId = "internal_happn"
	
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
	
	public func string(fromUserId userId: String?) -> String {
		return userId ?? "__officectl_internal__null_happn_id__"
	}
	
	public func userId(fromString string: String) throws -> String? {
		guard string != "__officectl_internal__null_happn_id__" else {
			return nil
		}
		return string
	}
	
	public func string(fromPersistentUserId pId: String) -> String {
		return pId
	}
	
	public func persistentUserId(fromString string: String) throws -> String {
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
		if userWrapper.sourceServiceId == config.serviceId, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserId: String?
		if userWrapper.sourceServiceId == config.serviceId {
			/* The underlying user (though absent) is from our service; the original id can be decoded as a valid id for our service. */
			inferredUserId = userWrapper.userId.id
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create a HappnUser")
			}
			inferredUserId = email.rawValue
		}
		
		var res = HappnUser(login: inferredUserId)
		if userWrapper.firstName != .unsupported {res.firstName = userWrapper.firstName}
		if userWrapper.lastName  != .unsupported {res.lastName  = userWrapper.lastName}
		if userWrapper.nickname  != .unsupported {res.nickname  = userWrapper.nickname}
		return res
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout HappnUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		var res = Set<DirectoryUserProperty>()
		/* For all changes below we nullify the record because changing the record is not something that is possible and
		 * we want the record wrapper and its underlying record to be in sync.
		 * So all changes to the wrapper must be done with a nullification of the underlying record. */
		for (property, value) in hints {
			switch property {
				case .userId:
					guard allowUserIdChange else {continue}
					user.login = value
					res.insert(.identifyingEmail)
					res.insert(.userId)
					
				case .identifyingEmail:
					guard allowUserIdChange else {continue}
					guard hints[.userId] == nil else {
						if hints[.userId] != value {
							OfficeKitConfig.logger?.warning("Invalid hints given for a HappnUser: both userId and identifyingEmail are defined with different values. Only userId will be used.")
						}
						continue
					}
					guard let email = value.flatMap({ Email(rawValue: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid value for an identifying email of a happn user.")
						continue
					}
					user.login = email.rawValue
					res.insert(.identifyingEmail)
					res.insert(.userId)
					
				case .persistentId:
					guard let id = value else {
						OfficeKitConfig.logger?.warning("Invalid value for a persistent id of a happn user.")
						continue
					}
					user.id = .set(id)
					res.insert(.persistentId)
					
				case .firstName:
					user.firstName = .set(value)
					res.insert(.firstName)
					
				case .lastName:
					user.lastName = .set(value)
					res.insert(.lastName)
					
				case .nickname:
					user.nickname = .set(value)
					res.insert(.nickname)
					
				case .password:
					guard let pass = value else {
						OfficeKitConfig.logger?.warning("The password of a happn user cannot be removed.")
						continue
					}
					OfficeKitConfig.logger?.warning("Setting the password of a happn user via hints can lead to unexpected results (including security flaws for this user). Please use the dedicated method to set the password in the service.")
					user.password = .set(pass)
					res.insert(.password)
					
				case .custom("gender"):
					guard let gender = value.flatMap({ HappnUser.Gender(rawValue: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid gender for a happn user.")
						continue
					}
					user.gender = .set(gender)
					
				case .custom("birthdate"):
					guard let birthdate = value.flatMap({ HappnUser.birthDateFormatter.date(from: $0) }) else {
						OfficeKitConfig.logger?.warning("Invalid gender for a happn user.")
						continue
					}
					user.birthDate = .set(birthdate)
					
				case .otherEmails, .custom:
					(/*nop (not supported)*/)
			}
		}
		return res
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> HappnUser? {
		/* TODO: Properties to fetch. */
		let eventLoop = try services.eventLoop()
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await happnConnector.connect(scope: GetHappnUserOperation.scopes)
		
		let op = GetHappnUserOperation(userKey: pId, connector: happnConnector)
		do {
			return try await EventLoopFuture<HappnUser>.future(from: op, on: eventLoop).map({ $0 as HappnUser? }).get()
		} catch let error as NSError where error.domain == "com.happn.officectl.happn" && error.code == 25002 {
			return nil
		}
	}
	
	public func existingUser(fromUserId uId: String?, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> HappnUser? {
		guard let uId = uId else {
			/* Yes.
			 * It’s ugly.
			 * But the only admin user with a nil login is 244. */
			return try await existingUser(fromPersistentId: HappnConnector.nullLoginUserId, propertiesToFetch: propertiesToFetch, using: services)
		}
		
		/* TODO: Properties to fetch. */
		let eventLoop = try services.eventLoop()
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await happnConnector.connect(scope: SearchHappnUsersOperation.scopes)
		
		let ids = Set(Email(rawValue: uId)?.allDomainVariants(aliasMap: self.globalConfig.domainAliases).map{ $0.rawValue } ?? [uId])
		let users = try await withThrowingTaskGroup(of: [HappnUser].self, returning: [HappnUser].self, body: { group in
			for id in ids {
				group.addTask{
					let op = SearchHappnUsersOperation(email: id, happnConnector: happnConnector)
					return try await EventLoopFuture<[HappnUser]>.future(from: op, on: eventLoop).get()
				}
			}
			
			var ret = [HappnUser]()
			while let users = try await group.next() {
				ret += users
			}
			return ret
		})
		guard users.count <= 1 else {
			throw InvalidArgumentError(message: "Given user id has more than one user found")
		}
		return users.first
	}
	
	public func listAllUsers(using services: Services) async throws -> [HappnUser] {
		let eventLoop = try services.eventLoop()
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await happnConnector.connect(scope: SearchHappnUsersOperation.scopes)
		
		let searchOp = SearchHappnUsersOperation(email: nil, happnConnector: happnConnector)
		return try await EventLoopFuture<[HappnUser]>.future(from: searchOp, on: eventLoop).get()
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: HappnUser, using services: Services) async throws -> HappnUser {
		let eventLoop = try services.eventLoop()
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		var user = user
		if user.password.value == nil {
			/* Creating a user without a password is not possible. Let’s generate a password!
			 * A long and complex one. */
			OfficeKitConfig.logger?.warning("Auto-generating a random password for happn user creation: creating a happn user w/o a password is not supported.")
			let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=+_-$!@#%^&*(){}[]'\\\";:/?.>,<§"
			user.password = .set(String((0..<64).map{ _ in chars.randomElement()! }))
		}
		
		try await happnConnector.connect(scope: CreateHappnUserOperation.scopes)
		
		let op = CreateHappnUserOperation(user: user, connector: happnConnector)
		return try await EventLoopFuture<HappnUser>.future(from: op, on: eventLoop).get()
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: HappnUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> HappnUser {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: HappnUser, using services: Services) async throws {
		let eventLoop = try services.eventLoop()
		let happnConnector: HappnConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await happnConnector.connect(scope: DeleteHappnUserOperation.scopes)
		
		let op = DeleteHappnUserOperation(user: user, connector: happnConnector)
		return try await EventLoopFuture<Void>.future(from: op, on: eventLoop).get()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: HappnUser, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		let happnConnector: HappnConnector = semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: happnConnector) as ResetHappnPasswordAction
	}
	
}
