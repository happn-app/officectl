/*
 * ErasureUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation

import NIO
import ServiceKit

import OfficeModel



public typealias AnyDSUPair = DSUPair<AnyUserDirectoryService>
public struct DSUPair<DirectoryServiceType : UserDirectoryService> : Hashable {
	
	public let service: DirectoryServiceType
	public let user: DirectoryServiceType.UserType
	
	public let serviceID: String
	public let taggedID: TaggedID
	
	public var dsuIDPair: DSUIDPair<DirectoryServiceType> {
		return DSUIDPair(service: service, userID: user.userID)
	}
	
	public init(service s: DirectoryServiceType, user u: DirectoryServiceType.UserType) {
		service = s
		user = u
		serviceID = service.config.serviceID
		taggedID = TaggedID(tag: serviceID, id: service.string(fromUserID: user.userID))
	}
	
	public init?<SourceServiceType : UserDirectoryService>(service s: SourceServiceType, user u: SourceServiceType.UserType) {
		guard let s: DirectoryServiceType = s.unbox() else {
			return nil
		}
		
		guard let u: DirectoryServiceType.UserType = u.unbox() else {
			/* In theory we can fatalError here.
			 * However, because we’re a library and must not crash, let’s play it safe. */
			OfficeKitConfig.logger?.error("Got impossible situation where service is unboxed to \(DirectoryServiceType.self), but the user is not unboxed to this directory user type!")
			return nil
		}
		
		self.init(service: s, user: u)
	}
	
	public func hop<NewDirectoryServiceType : UserDirectoryService>(to newService: NewDirectoryServiceType) throws -> DSUPair<NewDirectoryServiceType> {
		return try DSUPair<NewDirectoryServiceType>(service: newService, user: newService.logicalUser(fromUser: user, in: service))
	}
	
	public func passwordResetPair(using services: Services) throws -> DSPasswordResetPair<DirectoryServiceType>? {
		return try DSPasswordResetPair<DirectoryServiceType>(dsuPair: self, using: services)
	}
	
	public func userWrapper() throws -> DirectoryUserWrapper {
		return try service.wrappedUser(fromUser: user)
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggedID)
	}
	
	public static func ==(_ lhs: DSUPair<DirectoryServiceType>, _ rhs: DSUPair<DirectoryServiceType>) -> Bool {
		return lhs.taggedID == rhs.taggedID
	}
	
}

extension AnyDSUPair {
	
	public static func fetchAll(in services: Set<AnyUserDirectoryService>, using depServices: Services) async -> (dsuPairs: [AnyDSUPair], fetchErrorsByServices: [AnyUserDirectoryService: Error]) {
		return await withTaskGroup(
			of: (service: AnyUserDirectoryService, users: Result<[AnyDirectoryUser], Error>).self,
			returning: (dsuPairs: [AnyDSUPair], fetchErrorsByServices: [AnyUserDirectoryService: Error]).self,
			body: { group in
				for service in services {
					group.addTask{
						let usersResult = await Result{ try await service.listAllUsers(using: depServices) }
						return (service, usersResult)
					}
				}
				
				var dsuPairs = [AnyDSUPair]()
				var fetchErrorsByServices = [AnyUserDirectoryService: Error]()
				while let (service, usersResult) = await group.next() {
					assert(fetchErrorsByServices[service] == nil)
					assert(!dsuPairs.contains{ $0.service == service })
					switch usersResult {
						case .success(let users): dsuPairs.append(contentsOf: users.map{ AnyDSUPair(service: service, user: $0) })
						case .failure(let error): fetchErrorsByServices[service] = error
					}
				}
				return (dsuPairs, fetchErrorsByServices)
			}
		)
	}
	
}


public typealias AnyDSUIDPair = DSUIDPair<AnyUserDirectoryService>
public struct DSUIDPair<DirectoryServiceType : UserDirectoryService> : Hashable {
	
	public let service: DirectoryServiceType
	public let userID: DirectoryServiceType.UserType.IDType
	
	public let serviceID: String
	public let taggedID: TaggedID
	
	public init(service s: DirectoryServiceType, userID u: DirectoryServiceType.UserType.IDType) {
		service = s
		userID = u
		
		serviceID = service.config.serviceID
		taggedID = TaggedID(tag: serviceID, id: service.string(fromUserID: userID))
	}
	
	public init?<SourceServiceType : UserDirectoryService>(service s: SourceServiceType, user u: SourceServiceType.UserType) {
		guard let dsu = DSUPair<DirectoryServiceType>(service: s, user: u) else {
			return nil
		}
		
		service = dsu.service
		userID = dsu.user.userID
		
		serviceID = dsu.serviceID
		taggedID = dsu.taggedID
	}
	
	public init(taggedID tid: TaggedID, servicesProvider: OfficeKitServiceProvider) throws {
		service = try servicesProvider.getUserDirectoryService(id: tid.tag)
		userID = try service.userID(fromString: tid.id)
		
		serviceID = service.config.serviceID
		taggedID = tid
		
		if let logger = OfficeKitConfig.logger {
			let newTid = TaggedID(tag: service.config.serviceID, id: service.string(fromUserID: userID))
			if tid != newTid {
				logger.error("Got a tagged it whose service/userID conversion does not convert back to itself. Source = \(tid), New = \(newTid)")
			}
		}
	}
	
	public init(string: String, servicesProvider: OfficeKitServiceProvider) throws {
		let tid = TaggedID(string: string)
		try self.init(taggedID: tid, servicesProvider: servicesProvider)
	}
	
	public func dsuPair() throws -> DSUPair<DirectoryServiceType> {
		return try DSUPair(service: service, user: service.logicalUser(fromUserID: userID))
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggedID)
	}
	
	public static func ==(_ lhs: DSUIDPair<DirectoryServiceType>, _ rhs: DSUIDPair<DirectoryServiceType>) -> Bool {
		return lhs.taggedID == rhs.taggedID
	}
	
}


/** A PasswordReset, and its DSUPair. */
public typealias AnyDSPasswordResetPair = DSPasswordResetPair<AnyUserDirectoryService>
public struct DSPasswordResetPair<DirectoryServiceType : UserDirectoryService> {
	
	public let dsuPair: DSUPair<DirectoryServiceType>
	public let passwordReset: ResetPasswordAction
	
	public init?(dsuPair p: DSUPair<DirectoryServiceType>, using services: Services) throws {
		guard p.service.supportsPasswordChange else {
			return nil
		}
		
		dsuPair = p
		passwordReset = try p.service.changePasswordAction(for: p.user, using: services)
	}
	
}
