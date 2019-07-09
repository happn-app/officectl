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
	}
	
	public func string(from userId: JSON) -> String {
		return ""
	}
	
	public func userId(from string: String) throws -> JSON {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromEmail email: Email) throws -> GenericDirectoryUser? {
		throw NotImplementedError()
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType) throws -> GenericDirectoryUser? {
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: JSON, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: JSON, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser?> {
		throw NotImplementedError()
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[GenericDirectoryUser]> {
		throw NotImplementedError()
	}
	
	public let supportsUserCreation = false
	public func createUser(_ user: GenericDirectoryUser, on container: Container) throws -> Future<GenericDirectoryUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: GenericDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GenericDirectoryUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = false
	public func deleteUser(_ user: GenericDirectoryUser, on container: Container) throws -> Future<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: GenericDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		throw NotImplementedError()
	}
	
}
