/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericJSON
import NIO
import OpenCrypto
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
		return user.primaryEmail.stringValue
	}
	
	public func string(fromUserId userId: Email) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> Email {
		guard let e = Email(string: string) else {
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
		if userWrapper.sourceServiceId == config.serviceId {
			if let underlyingUser = userWrapper.underlyingUser {return try logicalUser(fromJSON: underlyingUser)}
			else {
				/* The generic user id from our service, but there is no underlying
				 * user… Let’s create a GoogleUser from the user id. */
				guard let email = Email(string: userWrapper.userId.id) else {
					throw InvalidArgumentError(message: "Got an invalid id for a GoogleService user.")
				}
				return GoogleUser(email: email)
			}
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
			throw InvalidArgumentError(message: "Cannot get an email from the user to create a GoogleUser")
		}
		var res = GoogleUser(email: email)
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
			if let email = hints[.userId].flatMap({ $0 }).flatMap({ Email(string: $0) }) {
				if hints[.identifyingEmail] != nil && hints[.identifyingEmail] != hints[.userId] {
					OfficeKitConfig.logger?.warning("Invalid hints given for a GoogleUser: both userId and identifyingEmail are defined with different values. Only userId will be used.")
				}
				user.primaryEmail = email
				res.insert(.userId)
			} else if let identifyingEmail = hints[.identifyingEmail].flatMap({ $0 }).flatMap({ Email(string: $0) }) {
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
			if let emails = try? emailsStrArray.map({ try nil2throw(Email(string: String($0))) }) {
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
			#warning("TODO")
//			if let passHash = try? SHA1.hash(Data(pass.utf8)) {
//				password = .set(passHash.reduce("", { $0 + String(format: "%02x", $1) }))
//				hashFunction = .set(.sha1)
//				changePasswordAtNextLogin = .set(false)
//			} else {
				OfficeKitConfig.logger?.warning("Cannot encrypt password. Won’t put it in Google User.")
//			}
		}
		return res
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<GoogleUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId email: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<GoogleUser?> {
		#warning("TODO: Implement propertiesToFetch")
		/* Note: We do **NOT** map the email to the main domain. Maybe we should? */
		let eventLoop = try services.eventLoop()
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let future = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: eventLoop)
		.flatMap{ _ -> EventLoopFuture<[GoogleUser]> in
			let op = SearchGoogleUsersOperation(searchedDomain: email.domain, query: #"email="\#(email.stringValue)""#, googleConnector: googleConnector)
			return EventLoopFuture<[GoogleUser]>.future(from: op, on: eventLoop)
		}
		.flatMapThrowing{ objects -> GoogleUser? in
			guard objects.count <= 1 else {
				throw UserIdConversionError.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
	public func listAllUsers(using services: Services) throws -> EventLoopFuture<[GoogleUser]> {
		let eventLoop = try services.eventLoop()
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		return googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: eventLoop)
		.flatMap{ _ in
			let futures = self.config.primaryDomains.map{ domain -> EventLoopFuture<[GoogleUser]> in
				let searchOp = SearchGoogleUsersOperation(searchedDomain: domain, query: "isSuspended=false", googleConnector: googleConnector)
				return EventLoopFuture<[GoogleUser]>.future(from: searchOp, on: eventLoop)
			}
			/* Merging all the users from all the domains. */
			return EventLoopFuture.reduce([GoogleUser](), futures, on: eventLoop, +)
		}
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GoogleUser, using services: Services) throws -> EventLoopFuture<GoogleUser> {
		let eventLoop = try services.eventLoop()
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		
		let op = CreateGoogleUserOperation(user: user, connector: googleConnector)
		return googleConnector.connect(scope: CreateGoogleUserOperation.scopes, eventLoop: eventLoop)
		.flatMap{ _ in EventLoopFuture<GoogleUser>.future(from: op, on: eventLoop) }
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<GoogleUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GoogleUser, using services: Services) throws -> EventLoopFuture<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: GoogleUser, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: googleConnector) as ResetGooglePasswordAction
	}
	
}
