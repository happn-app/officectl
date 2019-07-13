/*
 * ExternalDirectoryServiceV1.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericJSON
import Service



public class ExternalDirectoryServiceV1 : DirectoryService {
	
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
	
	public func string(from userId: GenericDirectoryUserId) -> String {
		return try! JSONEncoder().encode(userId.rawValue).base64EncodedString()
	}
	
	public func userId(from string: String) throws -> GenericDirectoryUserId {
		guard let jsonData = Data(base64Encoded: string) else {
			throw InvalidArgumentError(message: "Cannot decode base64 string")
		}
		let json = try JSONDecoder().decode(JSON.self, from: jsonData)
		guard let id = GenericDirectoryUserId(rawValue: json) else {
			throw InvalidArgumentError(message: "Invalid GenericDirectoryUserId id")
		}
		return id
	}
	
	public func shortDescription(from user: GenericDirectoryUser) -> String {
		return "\(user.userId)"
	}
	
	public func exportableJSON(from user: GenericDirectoryUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> GenericDirectoryUser? {
		guard config.supportsServiceIdForLogicalUserConversion("email") else {
			throw NotSupportedError(message: "Creating a user from an email is not supported for service \(config.serviceId)")
		}
		return GenericDirectoryUser(userId: .proxy(serviceId: "email", user: .string(email.stringValue)))
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> GenericDirectoryUser? {
		guard config.supportsServiceIdForLogicalUserConversion(service.config.serviceId) else {
			throw NotSupportedError(message: "Creating a user from service id \(service.config.serviceId) is not supported for service \(config.serviceId)")
		}
		let jsonUser = try service.exportableJSON(from: user)
		return GenericDirectoryUser(userId: .proxy(serviceId: service.config.serviceId, user: jsonUser))
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
	
	public func existingUser(fromUserId uId: GenericDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		guard let url = URL(string: "existing-user-from/user-id", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to retrieve existing user from user id")
		}
		
		struct Request : Encodable {
			var userId: JSON
			var propertiesToFetch: Set<String>
		}
		let request = Request(userId: uId.rawValue, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<GenericDirectoryUser?>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser?>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		guard let url = URL(string: "existing-user-from/email", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to retrieve existing user from email")
		}
		
		struct Request : Encodable {
			var email: Email
			var propertiesToFetch: Set<String>
		}
		let request = Request(email: email, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue }))
		let requestData = try jsonEncoder.encode(request)
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.httpBody = requestData
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		let operation = ApiRequestOperation<GenericDirectoryUser?>(request: urlRequest, authenticator: authenticator.authenticate, decoder: jsonDecoder)
		return Future<GenericDirectoryUser?>.future(from: operation, eventLoop: container.eventLoop).map{ try $0.getData() }
	}
	
	/* Sadly, cannot be embedded in generic function. */
	private struct ExistingUserFromUserRequest : Encodable {
		var serviceId: String
		var user: JSON
		var propertiesToFetch: Set<String>
	}
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		guard let url = URL(string: "existing-user-from/external-user", relativeTo: config.url) else {
			throw InternalError(message: "Cannot get external service URL to retrieve existing user from user in other service")
		}
		
		let jsonUser = try service.exportableJSON(from: user)
		let request = ExistingUserFromUserRequest(serviceId: service.config.serviceId, user: jsonUser, propertiesToFetch: Set(propertiesToFetch.map{ $0.rawValue }))
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
