/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/20.
 */

import Foundation

import Crypto
import Email
import GenericJSON
import NIO
import SemiSingleton
import UnwrapOrThrow

import ServiceKit



/**
 A Gougle Apps service.
 
 Dependencies:
 - Event-loop;
 - Semi-singleton store. */
public final class GoogleService : UserDirectoryService {
	
	public static let providerID = "internal_google"
	
	public enum UserIDConversionError : Error {
		
		case noEmailInLDAP
		case multipleEmailInLDAP
		
		case tooManyUsersFound
		case unsupportedServiceUserIDConversion
		
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
	
	public func string(fromUserID userID: Email) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> Email {
		guard let e = Email(rawValue: string) else {
			throw InvalidArgumentError(message: "The given string is not a valid email: \(string)")
		}
		return e
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: GoogleUser) throws -> JSON {
		/* Probably not optimal in terms of speed, but works well and avoids having a shit-ton of glue to create in the GoogleUser (or in this method). */
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> GoogleUser {
		/* Probably not optimal in terms of speed, but works well and avoids having a shit-ton of glue to create in the GoogleUser (or in this method). */
		let encoded = try JSONEncoder().encode(json)
		return try JSONDecoder().decode(GoogleUser.self, from: encoded)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> GoogleUser {
		if userWrapper.sourceServiceID == config.serviceID, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserID: Email
		if userWrapper.sourceServiceID == config.serviceID {
			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
			guard let email = Email(rawValue: userWrapper.userID.id) else {
				throw InvalidArgumentError(message: "Got an invalid ID for a GoogleService user.")
			}
			inferredUserID = email
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create a GoogleUser")
			}
			inferredUserID = email
		}
		
		var res = GoogleUser(email: inferredUserID)
		if let otherEmails = userWrapper.otherEmails {res.aliases = otherEmails}
		if let firstName = userWrapper.firstName.flatMap({ $0 }), let lastName = userWrapper.lastName.flatMap({ $0 }) {
			res.name = GoogleUser.Name(givenName: firstName, familyName: lastName, fullName: firstName + " " + lastName)
		}
		return res
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout GoogleUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		/* TODO: Maybe migrate this to a switch one day… */
		var res = Set<DirectoryUserProperty>()
		if allowUserIDChange {
			if let email = hints[.userID].flatMap({ $0 }).flatMap({ Email(rawValue: $0) }) {
				if hints[.identifyingEmail] != nil && hints[.identifyingEmail] != hints[.userID] {
					OfficeKitConfig.logger?.warning("Invalid hints given for a GoogleUser: both userID and identifyingEmail are defined with different values. Only userID will be used.")
				}
				user.primaryEmail = email
				res.insert(.userID)
			} else if let identifyingEmail = hints[.identifyingEmail].flatMap({ $0 }).flatMap({ Email(rawValue: $0) }) {
				user.primaryEmail = identifyingEmail
				res.insert(.identifyingEmail)
			}
		}
		if let persistentID = hints[.persistentID].flatMap({ $0 }) {
			user.id = persistentID
			res.insert(.persistentID)
		}
		if let otherEmailsStr = hints[.otherEmails].flatMap({ $0 }) {
			/* Yes.
			 * We cannot represent an element in the list which contains a comma.
			 * Maybe one day we’ll do the generic thing… */
			let emailsStrArray = otherEmailsStr.split(separator: ",")
			if let emails = try? emailsStrArray.map({ try Email(rawValue: String($0)) ?! Err.genericError("Found invalid email in \(emailsStrArray) from otherEmails hints in gougle service.") }) {
				user.aliases = emails
				res.insert(.otherEmails)
			}
		}
		if let firstName = hints[.firstName].flatMap({ $0 }), let lastName = hints[.lastName].flatMap({ $0 }) {
			user.name = GoogleUser.Name(givenName: firstName, familyName: lastName, fullName: firstName + " " + lastName)
			res.insert(.firstName)
			res.insert(.lastName)
		}
		if let pass = hints[.password].flatMap({ $0 }) {
			let sha1 = Insecure.SHA1.hash(data: Data(pass.utf8))
			user.password = sha1.reduce("", { $0 + String(format: "%02x", $1) })
			user.hashFunction = .sha1
			user.changePasswordAtNextLogin = false
		}
		return res
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> GoogleUser? {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserID email: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> GoogleUser? {
		/* Note: We do **NOT** map the email to the main domain. Maybe we should? */
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		/* TODO: Implement propertiesToFetch. */
		let op = SearchGoogleUsersOperation(searchedDomain: email.domainPart, query: #"email="\#(email.rawValue)""#, googleConnector: googleConnector)
		let objects = try await services.opQ.addOperationAndGetResult(op)
		
		guard objects.count <= 1 else {
			throw UserIDConversionError.tooManyUsersFound
		}
		return objects.first
	}
	
	public func listAllUsers(using services: Services) async throws -> [GoogleUser] {
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await googleConnector.connect(scope: SearchGoogleUsersOperation.scopes)
		
		let ops = config.primaryDomains.map{ SearchGoogleUsersOperation(searchedDomain: $0, query: "isSuspended=false", googleConnector: googleConnector) }
		return try await services.opQ.addOperationsAndGetResults(ops).map{ try $0.get() }.flatMap{ $0 }
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GoogleUser, using services: Services) async throws -> GoogleUser {
		let googleConnector: GoogleJWTConnector = try services.semiSingleton(forKey: config.connectorSettings)
		try await googleConnector.connect(scope: CreateGoogleUserOperation.scopes)
		
		let op = CreateGoogleUserOperation(user: user, connector: googleConnector)
		return try await services.opQ.addOperationAndGetResult(op)
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
