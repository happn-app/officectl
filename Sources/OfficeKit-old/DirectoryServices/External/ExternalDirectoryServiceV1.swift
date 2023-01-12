/*
 * ExternalDirectoryServiceV1.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/20.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import GenericJSON
import SemiSingleton
import NIO
import ServiceKit
import URLRequestOperation

import OfficeModel



/**
 A service that uses an external http service to handle the requests.
 
 Dependencies:
 - Event-loop
 - Semi-singleton store */
public final class ExternalDirectoryServiceV1 : UserDirectoryService {
	
	public static let providerID = "http_service_v1"
	
	public typealias ConfigType = ExternalDirectoryServiceV1Config
	public typealias UserType = DirectoryUserWrapper
	
	public let config: ExternalDirectoryServiceV1Config
	public let globalConfig: GlobalConfig
	
	public init(config c: ExternalDirectoryServiceV1Config, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
		
		authenticator = ExternalServiceAuthenticator(secret: c.secret)
		
#warning("TODO: JSON encoder/decoder are thread-safe on macOS 13, not before apparently (conformance to Sendable is only starting at macOS 13)")
		/* Note: We assume JSON encoder/decoder are thread-safe (<https://stackoverflow.com/a/52183880>). */
		
		jsonEncoder = JSONEncoder()
//		jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
		
		jsonDecoder = JSONDecoder()
//		jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
	}
	
	public func shortDescription(fromUser user: DirectoryUserWrapper) -> String {
		return "\(user.userID)"
	}
	
	public func string(fromUserID userID: TaggedID) -> String {
		return userID.stringValue
	}
	
	public func userID(fromString string: String) throws -> TaggedID {
		return TaggedID(string: string)
	}
	
	public func string(fromPersistentUserID pID: TaggedID) -> String {
		return pID.stringValue
	}
	
	public func persistentUserID(fromString string: String) throws -> TaggedID {
		return TaggedID(string: string)
	}
	
	public func json(fromUser user: DirectoryUserWrapper) throws -> JSON {
		return user.json()
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> DirectoryUserWrapper {
		return try DirectoryUserWrapper(json: json, forcedUserID: nil)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> DirectoryUserWrapper {
		if userWrapper.sourceServiceID == config.serviceID, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserID: TaggedID
		if userWrapper.sourceServiceID == config.serviceID {
			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
			inferredUserID = TaggedID(string: userWrapper.userID.id)
		} else {
			var idStr: String?
			for s in config.wrappedUserToUserIDConversionStrategies where idStr == nil {
				idStr = try? s.convertUserToID(userWrapper, globalConfig: globalConfig)
			}
			guard let foundIDStr = idStr else {
				throw InvalidArgumentError(message: "No conversion strategy matches user \(userWrapper)")
			}
			inferredUserID = TaggedID(string: foundIDStr)
		}
		
		var ret = DirectoryUserWrapper(userID: inferredUserID)
		ret.identifyingEmail = userWrapper.identifyingEmail
		ret.otherEmails = userWrapper.otherEmails
		ret.firstName = userWrapper.firstName
		ret.lastName = userWrapper.lastName
		ret.nickname = userWrapper.nickname
		return ret
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout DirectoryUserWrapper, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		return user.applyAndSaveHints(hints, blacklistedKeys: (allowUserIDChange ? [] : [.userID]))
	}
	
	public func existingUser(fromPersistentID pID: TaggedID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> DirectoryUserWrapper? {
		let operation = try ApiRequestOperation<DirectoryUserWrapper?>.forAPIRequest(
			url: config.url.appending("existing-user-from", "persistent-id"), method: "POST",
			httpBody: Request(persistentID: pID, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue })),
			decoders: [jsonDecoder], requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await services.opQ.addOperationAndGetResult(operation).result.getData()
		
		struct Request : Encodable {
			var persistentID: TaggedID
			var propertiesToFetch: Set<String>
		}
	}
	
	public func existingUser(fromUserID uID: TaggedID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> DirectoryUserWrapper? {
		let operation = try ApiRequestOperation<DirectoryUserWrapper?>.forAPIRequest(
			url: config.url.appending("existing-user-from", "user-id"), method: "POST",
			httpBody: Request(userID: uID, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue })),
			decoders: [jsonDecoder], requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await services.opQ.addOperationAndGetResult(operation).result.getData()
		
		struct Request : Encodable {
			var userID: TaggedID
			var propertiesToFetch: Set<String>
		}
	}
	
	public func listAllUsers(using services: Services) async throws -> [DirectoryUserWrapper] {
		let operation = ApiRequestOperation<[DirectoryUserWrapper]>.forAPIRequest(
			url: config.url.appendingPathComponent("list-all-users"),
			decoders: [jsonDecoder], requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await services.opQ.addOperationAndGetResult(operation).result.getData()
	}
	
	public var supportsUserCreation: Bool {return config.supportsUserCreation}
	public func createUser(_ user: DirectoryUserWrapper, using services: Services) async throws -> DirectoryUserWrapper {
		let operation = try ApiRequestOperation<DirectoryUserWrapper>.forAPIRequest(
			url: config.url.appendingPathComponent("create-user"), method: "POST", httpBody: Request(user: user),
			decoders: [jsonDecoder], requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await services.opQ.addOperationAndGetResult(operation).result.getData()
		
		struct Request : Encodable {
			var user: DirectoryUserWrapper
		}
	}
	
	public var supportsUserUpdate: Bool {return config.supportsUserUpdate}
	public func updateUser(_ user: DirectoryUserWrapper, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> DirectoryUserWrapper {
		let operation = try ApiRequestOperation<DirectoryUserWrapper>.forAPIRequest(
			url: config.url.appendingPathComponent("update-user"), method: "POST",
			httpBody: Request(user: user, propertiesToUpdate: Set(propertiesToUpdate.map{ $0.rawValue })),
			decoders: [jsonDecoder], requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await services.opQ.addOperationAndGetResult(operation).result.getData()
		
		struct Request : Encodable {
			var user: DirectoryUserWrapper
			var propertiesToUpdate: Set<String>
		}
	}
	
	public var supportsUserDeletion: Bool {return config.supportsUserDeletion}
	public func deleteUser(_ user: DirectoryUserWrapper, using services: Services) async throws {
		let operation = try ApiRequestOperation<String>.forAPIRequest(
			url: config.url.appendingPathComponent("delete-user"), method: "POST", httpBody: Request(user: user),
			decoders: [jsonDecoder], requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		_ = try await services.opQ.addOperationAndGetResult(operation).result.getData()
		
		struct Request : Encodable {
			var user: DirectoryUserWrapper
		}
	}
	
	public var supportsPasswordChange: Bool {return config.supportsPasswordChange}
	public func changePasswordAction(for user: DirectoryUserWrapper, using services: Services) throws -> ResetPasswordAction {
		let semiSingletonStore = try services.semiSingletonStore()
		return semiSingletonStore.semiSingleton(forKey: user.userID, additionalInitInfo: (config.url, authenticator)) as ResetExternalServicePasswordAction
	}
	
	private typealias ApiRequestOperation<T : Decodable> = URLRequestDataOperation<ExternalServiceResponse<T>>
	
	private let jsonEncoder: JSONEncoder
	private let jsonDecoder: JSONDecoder
	
	private let authenticator: ExternalServiceAuthenticator
	
}
