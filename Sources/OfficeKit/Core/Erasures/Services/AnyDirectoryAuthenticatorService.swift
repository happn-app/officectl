/*
 * AnyDirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/28.
 */

import Foundation

import NIO
import ServiceKit



private protocol DirectoryAuthenticatorServiceBox {
	
	func authenticate(userId: AnyId, challenge: Any, using services: Services) async throws -> Bool
	func validateAdminStatus(userId: AnyId, using services: Services) async throws -> Bool
	
}

private struct ConcreteDirectoryAuthenticatorBox<Base : DirectoryAuthenticatorService> : DirectoryAuthenticatorServiceBox {
	
	let originalAuthenticator: Base
	
	func authenticate(userId: AnyId, challenge: Any, using services: Services) async throws -> Bool {
		guard let uid: Base.UserType.IdType = userId.unbox(), let c = challenge as? Base.AuthenticationChallenge else {
			throw InvalidArgumentError(message: "Got invalid user id (\(userId)) or auth challenge (\(challenge)) to authenticate with a directory service authenticator of type \(Base.self)")
		}
		return try await originalAuthenticator.authenticate(userId: uid, challenge: c, using: services)
	}
	
	func validateAdminStatus(userId: AnyId, using services: Services) async throws -> Bool {
		guard let uid: Base.UserType.IdType = userId.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user id type (\(userId)) to check if user is admin with a directory service authenticator of type \(Base.self)")
		}
		return try await originalAuthenticator.validateAdminStatus(userId: uid, using: services)
	}
	
}

public class AnyDirectoryAuthenticatorService : AnyUserDirectoryService, DirectoryAuthenticatorService {
	
	public typealias AuthenticationChallenge = Any
	
	/* About the init here.
	 *
	 * Before latest Swift to date (running on master rn for bugfix reasons on Linux),
	 * we could override super’s init with (super init argument used to be unnamed):
	 *    override init<T : DirectoryAuthenticatorService>(_ object: T)
	 *
	 * W/ latest Swift we get an error that we’re overriding with incompatible argument type (which tbf is not wrong).
	 * For now we simply dissociate the init w/ a DirectoryService and a DirectoryAuthenticatorService, and crash w/ a DirectoryService in the AnyDirectoryAuthenticatorService.
	 *
	 * A better solution would be for AnyDirectoryAuthenticatorService not to inherit from AnyDirectoryService and implement all the methods from DirectoryService too,
	 * keeping an AnyDirectoryService internally if needed.
	 *
	 * I’m not doing that for now because I don’t have a codegen setup (yet?)
	 * and it’d be a pain to copy and modify two erasures each time there’s a modification in the DirectoryService… */
	
	override init<T : UserDirectoryService>(uds object: T) {
		fatalError()
	}
	
	init<T : DirectoryAuthenticatorService>(das object: T) {
		box = ConcreteDirectoryAuthenticatorBox(originalAuthenticator: object)
		super.init(uds: object)
	}
	
	public required init(config c: AnyOfficeKitServiceConfig, globalConfig gc: GlobalConfig) {
		fatalError("init(config:globalConfig:) unavailable for a directory authenticator service erasure")
	}
	
	public func authenticate(userId: AnyId, challenge: Any, using services: Services) async throws -> Bool {
		return try await box.authenticate(userId: userId, challenge: challenge, using: services)
	}
	
	public func validateAdminStatus(userId: AnyId, using services: Services) async throws -> Bool {
		return try await box.validateAdminStatus(userId: userId, using: services)
	}
	
	fileprivate let box: DirectoryAuthenticatorServiceBox
	
}


extension DirectoryAuthenticatorService {
	
	public func erase() -> AnyDirectoryAuthenticatorService {
		if let erased = self as? AnyDirectoryAuthenticatorService {
			return erased
		}
		
		return AnyDirectoryAuthenticatorService(das: self)
	}
	
	public func unbox<DirectoryType : DirectoryAuthenticatorService>() -> DirectoryType? {
		guard let anyAuth = self as? AnyDirectoryAuthenticatorService, !(DirectoryType.self is AnyDirectoryAuthenticatorService.Type) else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyAuth.box as? ConcreteDirectoryAuthenticatorBox<DirectoryType>)?.originalAuthenticator ?? (anyAuth.box as? ConcreteDirectoryAuthenticatorBox<AnyDirectoryAuthenticatorService>)?.originalAuthenticator.unbox()
	}
	
}
