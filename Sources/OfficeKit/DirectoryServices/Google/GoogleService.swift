/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Crypto
import Email
import GenericJSON
import NIO
import SemiSingleton
import ServiceKit



/** A Googl Apps service.

Dependencies:
- Event-loop
- Semi-singleton store */
public final class GoogleService : UserDirectoryService {
	
	public static let providerId = "internal_google"
	
	public enum UserIdConversionError : Error {
		
		case noEmailInLDAP
		case multipleEmailInLDAP
		
		case tooManyUsersFound
		case unsupportedServiceUserIdConversion
		
		case internalError
		
	}
	
	public typealias ConfigType = GoogleServiceConfig
	public typealias UserType = GoogleUser
	
	public let config: GoogleServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: GoogleUser) -> String {
		return user.primaryEmail.rawValue
	}
	
	public func string(fromUserId userId: Email) -> String {
		return userId.rawValue
	}
	
	public func userId(fromString string: String) throws -> Email {
		guard let e = Email(rawValue: string) else {
			throw InvalidArgumentError(message: "The given string is not a valid email: \(string)")
		}
		return e
	}
	
	public func string(fromPersistentUserId pId: String) -> String {
		return pId
	}
	
	public func persistentUserId(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: GoogleUser) throws -> JSON {
		/* Probably not optimal in terms of speed, but works well and avoids
		 * having a shit-ton of glue to create in the GoogleUser (or in this
		 * method). */
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> GoogleUser {
		/* Probably not optimal in terms of speed, but works well and avoids
		 * having a shit-ton of glue to create in the GoogleUser (or in this
		 * method). */
		let encoded = try JSONEncoder().encode(json)
		return try JSONDecoder().decode(GoogleUser.self, from: encoded)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> GoogleUser {
		if userWrapper.sourceServiceId == config.serviceId, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserId: Email
		if userWrapper.sourceServiceId == config.serviceId {
			/* The underlying user (though absent) is from our service; the
			 * original id can be decoded as a valid id for our service. */
			guard let email = Email(rawValue: userWrapper.userId.id) else {
				throw InvalidArgumentError(message: "Got an invalid id for a GoogleService user.")
			}
			inferredUserId = email
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create a GoogleUser")
			}
			inferredUserId = email
		}
		
		var res = GoogleUser(email: inferredUserId)
		if let otherEmails = userWrapper.otherEmails.value {res.aliases = .set(otherEmails)}
		if let firstName = userWrapper.firstName.value.flatMap({ $0 }), let lastName = userWrapper.lastName.value.flatMap({ $0 }) {
			res.name = .set(GoogleUser.Name(givenName: firstName, familyName: lastName, fullName: firstName + " " + lastName))
		}
		return res
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout GoogleUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		/* TODO: Maybe migrate this to a switch one day… */
		var res = Set<DirectoryUserProperty>()
		if allowUserIdChange {
			if let email = hints[.userId].flatMap({ $0 }).flatMap({ Email(rawValue: $0) }) {
				if hints[.identifyingEmail] != nil && hints[.identifyingEmail] != hints[.userId] {
					OfficeKitConfig.logger?.warning("Invalid hints given for a GoogleUser: both userId and identifyingEmail are defined with different values. Only userId will be used.")
				}
				user.primaryEmail = email
				res.insert(.userId)
			} else if let identifyingEmail = hints[.identifyingEmail].flatMap({ $0 }).flatMap({ Email(rawValue: $0) }) {
				user.primaryEmail = identifyingEmail
				res.insert(.identifyingEmail)
			}
		}
		if let persistentId = hints[.persistentId].flatMap({ $0 }) {
			user.id = .set(persistentId)
			res.insert(.persistentId)
		}
		if let otherEmailsStr = hints[.otherEmails].flatMap({ $0 }) {
			/* Yes. We cannot represent an element in the list which contains a
			 * comma. Maybe one day we’ll do the generic thing… */
			let emailsStrArray = otherEmailsStr.split(separator: ",")
			if let emails = try? emailsStrArray.map({ try nil2throw(Email(rawValue: String($0))) }) {
				user.aliases = .set(emails)
				res.insert(.otherEmails)
			}
		}
		if let firstName = hints[.firstName].flatMap({ $0 }), let lastName = hints[.lastName].flatMap({ $0 }) {
			user.name = .set(GoogleUser.Name(givenName: firstName, familyName: lastName, fullName: firstName + " " + lastName))
			res.insert(.firstName)
			res.insert(.lastName)
		}
		if let pass = hints[.password].flatMap({ $0 }) {
			let sha1 = Insecure.SHA1.hash(data: Data(pass.utf8))
			user.password = .set(sha1.reduce("", { $0 + String(format: "%02x", $1) }))
			user.hashFunction = .set(.sha1)
			user.changePasswordAtNextLogin = .set(false)
		}
		return res
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> GoogleUser? {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId email: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> GoogleUser? {
		#warning("TODO: Implement propertiesToFetch")
		/* Note: We do **NOT** map the email to the main domain. Maybe we should? */
		let eventLoop = try services.eventLoop()
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		let op = SearchGoogleUsersOperation(searchedDomain: email.domainPart, query: #"email="\#(email.rawValue)""#, googleConnector: googleConnector)
		let objects = try await EventLoopFuture<[GoogleUser]>.future(from: op, on: eventLoop).get()
		guard objects.count <= 1 else {
			throw UserIdConversionError.tooManyUsersFound
		}
		return objects.first
	}
	
	public func listAllUsers(using services: Services) async throws -> [GoogleUser] {
		let eventLoop = try services.eventLoop()
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		return try await withThrowingTaskGroup(of: [GoogleUser].self, returning: [GoogleUser].self, body: { group in
			for domain in config.primaryDomains {
				group.addTask{
					let searchOp = SearchGoogleUsersOperation(searchedDomain: domain, query: "isSuspended=false", googleConnector: googleConnector)
					return try await EventLoopFuture<[GoogleUser]>.future(from: searchOp, on: eventLoop).get()
				}
			}
			
			var ret = [GoogleUser]()
			while let users = try await group.next() {
				ret += users
			}
			return ret
		})
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GoogleUser, using services: Services) async throws -> GoogleUser {
		let eventLoop = try services.eventLoop()
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let op = CreateGoogleUserOperation(user: user, connector: googleConnector)
		try await googleConnector.connect(scope: CreateGoogleUserOperation.scopes)
		return try await EventLoopFuture<GoogleUser>.future(from: op, on: eventLoop).get()
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> GoogleUser {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GoogleUser, using services: Services) async throws {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: GoogleUser, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: googleConnector) as ResetGooglePasswordAction
	}
	
}
