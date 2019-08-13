/*
 * ExternalDirectoryServiceV1.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericJSON
import Service



public final class ExternalDirectoryServiceV1 : DirectoryService {
	
	public static let providerId = "http_service_v1"
	
	public typealias ConfigType = ExternalDirectoryServiceV1Config
	public typealias UserType = GenericDirectoryUser
	
	public let config: ExternalDirectoryServiceV1Config
	
	public init(config c: ExternalDirectoryServiceV1Config) {
		config = c
		authenticator = ExternalServiceAuthenticator(secret: c.secret)
		
		/* Note: We assume JSON encoder/decoder are thread-safe.
		 *       https://stackoverflow.com/a/52183880 */
		
		jsonEncoder = JSONEncoder()
//		jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
		
		jsonDecoder = JSONDecoder()
//		jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
	}
	
	public func shortDescription(from user: GenericDirectoryUser) -> String {
		return "\(user.userId)"
	}
	
	public func string(fromUserId userId: TaggedId) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> TaggedId {
		return TaggedId(string: string)
	}
	
	public func genericUser(fromUser user: GenericDirectoryUser) throws -> GenericDirectoryUser {
		return user
	}
	
	public func logicalUser(fromGenericUser genericUser: GenericDirectoryUser) throws -> GenericDirectoryUser {
		return genericUser
	}
	
	public func existingUser(fromPersistentId pId: JSON, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		guard let url = URL(string: "existing-user-from/persistent-id", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to retrieve existing user from persistent id")
		}
		
		struct Request : Encodable {
			var persistentId: JSON
			var propertiesToFetch: Set<String>
		}
		let request = Request(persistentId: pId, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<GenericDirectoryUser?>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser?>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	public func existingUser(fromUserId uId: TaggedId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
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
		
		let operation = ApiRequestOperation<GenericDirectoryUser?>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser?>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[GenericDirectoryUser]> {
		guard let url = URL(string: "list-all-users", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to list all users")
		}
		
		let operation = ApiRequestOperation<[GenericDirectoryUser]>(url: url, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<[GenericDirectoryUser]>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	public var supportsUserCreation: Bool {return config.supportsUserCreation}
	public func createUser(_ user: GenericDirectoryUser, on container: Container) throws -> Future<GenericDirectoryUser> {
		guard let url = URL(string: "create-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to create a user")
		}
		
		struct Request : Encodable {
			var user: GenericDirectoryUser
		}
		let request = Request(user: user)
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<GenericDirectoryUser>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	public var supportsUserUpdate: Bool {return config.supportsUserUpdate}
	public func updateUser(_ user: GenericDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser> {
		guard let url = URL(string: "update-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to update a user")
		}
		
		struct Request : Encodable {
			var user: GenericDirectoryUser
			var propertiesToUpdate: Set<String>
		}
		let request = Request(user: user, propertiesToUpdate: Set(propertiesToUpdate.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<GenericDirectoryUser>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	public var supportsUserDeletion: Bool {return config.supportsUserDeletion}
	public func deleteUser(_ user: GenericDirectoryUser, on container: Container) throws -> Future<Void> {
		guard let url = URL(string: "delete-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to delete a user")
		}
		
		struct Request : Encodable {
			var user: GenericDirectoryUser
		}
		let request = Request(user: user)
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<String>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser>.future(from: operation, eventLoop: container.eventLoop).map{ _ in () }
	}
	
	public var supportsPasswordChange: Bool {return config.supportsPasswordChange}
	public func changePasswordAction(for user: GenericDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		return try container.makeSemiSingleton(forKey: user.userId, additionalInitInfo: (config.url, authenticator, jsonEncoder, jsonDecoder)) as ResetExternalServicePasswordAction
	}
	
	private typealias ApiRequestOperation<T : Decodable> = AuthenticatedJSONOperation<ExternalServiceResponse<T>>
	
	private let jsonEncoder: JSONEncoder
	private let jsonDecoder: JSONDecoder
	
	private let authenticator: ExternalServiceAuthenticator
	
}
