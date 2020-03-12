/*
 * ExternalDirectoryServiceV1.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import GenericJSON
import SemiSingleton
import NIO
import ServiceKit



/** A service that uses an external http service to handle the requests.

Dependencies:
- Event-loop
- Semi-singleton store */
public final class ExternalDirectoryServiceV1 : UserDirectoryService {
	
	public static let providerId = "http_service_v1"
	
	public typealias ConfigType = ExternalDirectoryServiceV1Config
	public typealias UserType = DirectoryUserWrapper
	
	public let config: ExternalDirectoryServiceV1Config
	public let globalConfig: GlobalConfig
	
	public init(config c: ExternalDirectoryServiceV1Config, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
		
		authenticator = ExternalServiceAuthenticator(secret: c.secret)
		
		/* Note: We assume JSON encoder/decoder are thread-safe.
		 *       https://stackoverflow.com/a/52183880 */
		
		jsonEncoder = JSONEncoder()
//		jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
		
		jsonDecoder = JSONDecoder()
//		jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
	}
	
	public func shortDescription(fromUser user: DirectoryUserWrapper) -> String {
		return "\(user.userId)"
	}
	
	public func string(fromUserId userId: TaggedId) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> TaggedId {
		return TaggedId(string: string)
	}
	
	public func string(fromPersistentUserId pId: TaggedId) -> String {
		return pId.stringValue
	}
	
	public func persistentUserId(fromString string: String) throws -> TaggedId {
		return TaggedId(string: string)
	}
	
	public func json(fromUser user: DirectoryUserWrapper) throws -> JSON {
		return user.json()
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> DirectoryUserWrapper {
		return try DirectoryUserWrapper(json: json, forcedUserId: nil)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> DirectoryUserWrapper {
		if userWrapper.sourceServiceId == config.serviceId, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserId: TaggedId
		if userWrapper.sourceServiceId == config.serviceId {
			/* The underlying user (though absent) is from our service; the
			 * original id can be decoded as a valid id for our service. */
			inferredUserId = TaggedId(string: userWrapper.userId.id)
		} else {
			var idStr: String?
			for s in config.wrappedUserToUserIdConversionStrategies where idStr == nil {
				idStr = try? s.convertUserToId(userWrapper, globalConfig: globalConfig)
			}
			guard let foundIdStr = idStr else {
				throw InvalidArgumentError(message: "No conversion strategy matches user \(userWrapper)")
			}
			inferredUserId = TaggedId(string: foundIdStr)
		}
		
		var ret = DirectoryUserWrapper(userId: inferredUserId)
		ret.identifyingEmail = userWrapper.identifyingEmail
		ret.otherEmails = userWrapper.otherEmails
		ret.firstName = userWrapper.firstName
		ret.lastName = userWrapper.lastName
		ret.nickname = userWrapper.nickname
		return ret
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout DirectoryUserWrapper, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		return user.applyAndSaveHints(hints, blacklistedKeys: (allowUserIdChange ? [] : [.userId]))
	}
	
	public func existingUser(fromPersistentId pId: TaggedId, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<DirectoryUserWrapper?> {
		let eventLoop = try services.eventLoop()
		
		guard let url = URL(string: "existing-user-from/persistent-id", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to retrieve existing user from persistent id")
		}
		
		struct Request : Encodable {
			var persistentId: TaggedId
			var propertiesToFetch: Set<String>
		}
		let request = Request(persistentId: pId, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<DirectoryUserWrapper?>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return EventLoopFuture<ExternalServiceResponse<DirectoryUserWrapper?>>.future(from: operation, on: eventLoop).flatMapThrowing{ try $0.getData() }
	}
	
	public func existingUser(fromUserId uId: TaggedId, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<DirectoryUserWrapper?> {
		let eventLoop = try services.eventLoop()
		
		guard let url = URL(string: "existing-user-from/user-id", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to retrieve existing user from user id")
		}
		
		struct Request : Encodable {
			var userId: TaggedId
			var propertiesToFetch: Set<String>
		}
		let request = Request(userId: uId, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<DirectoryUserWrapper?>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return EventLoopFuture<ExternalServiceResponse<DirectoryUserWrapper?>>.future(from: operation, on: eventLoop).flatMapThrowing{ try $0.getData() }
	}
	
	public func listAllUsers(using services: Services) throws -> EventLoopFuture<[DirectoryUserWrapper]> {
		let eventLoop = try services.eventLoop()
		
		guard let url = URL(string: "list-all-users", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to list all users")
		}
		
		let operation = ApiRequestOperation<[DirectoryUserWrapper]>(url: url, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return EventLoopFuture<ExternalServiceResponse<[DirectoryUserWrapper]>>.future(from: operation, on: eventLoop).flatMapThrowing{ try $0.getData() }
	}
	
	public var supportsUserCreation: Bool {return config.supportsUserCreation}
	public func createUser(_ user: DirectoryUserWrapper, using services: Services) throws -> EventLoopFuture<DirectoryUserWrapper> {
		let eventLoop = try services.eventLoop()
		
		guard let url = URL(string: "create-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to create a user")
		}
		
		struct Request : Encodable {
			var user: DirectoryUserWrapper
		}
		let request = Request(user: user)
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<DirectoryUserWrapper>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return EventLoopFuture<ExternalServiceResponse<DirectoryUserWrapper>>.future(from: operation, on: eventLoop).flatMapThrowing{ try $0.getData() }
	}
	
	public var supportsUserUpdate: Bool {return config.supportsUserUpdate}
	public func updateUser(_ user: DirectoryUserWrapper, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<DirectoryUserWrapper> {
		let eventLoop = try services.eventLoop()
		
		guard let url = URL(string: "update-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to update a user")
		}
		
		struct Request : Encodable {
			var user: DirectoryUserWrapper
			var propertiesToUpdate: Set<String>
		}
		let request = Request(user: user, propertiesToUpdate: Set(propertiesToUpdate.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<DirectoryUserWrapper>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return EventLoopFuture<ExternalServiceResponse<DirectoryUserWrapper>>.future(from: operation, on: eventLoop).flatMapThrowing{ try $0.getData() }
	}
	
	public var supportsUserDeletion: Bool {return config.supportsUserDeletion}
	public func deleteUser(_ user: DirectoryUserWrapper, using services: Services) throws -> EventLoopFuture<Void> {
		let eventLoop = try services.eventLoop()
		
		guard let url = URL(string: "delete-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to delete a user")
		}
		
		struct Request : Encodable {
			var user: DirectoryUserWrapper
		}
		let request = Request(user: user)
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<String>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return EventLoopFuture<DirectoryUserWrapper>.future(from: operation, on: eventLoop).map{ _ in () }
	}
	
	public var supportsPasswordChange: Bool {return config.supportsPasswordChange}
	public func changePasswordAction(for user: DirectoryUserWrapper, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		return semiSingletonStore.semiSingleton(forKey: user.userId, additionalInitInfo: (config.url, authenticator, jsonEncoder, jsonDecoder)) as ResetExternalServicePasswordAction
	}
	
	private typealias ApiRequestOperation<T : Decodable> = AuthenticatedJSONOperation<ExternalServiceResponse<T>>
	
	private let jsonEncoder: JSONEncoder
	private let jsonDecoder: JSONDecoder
	
	private let authenticator: ExternalServiceAuthenticator
	
}
