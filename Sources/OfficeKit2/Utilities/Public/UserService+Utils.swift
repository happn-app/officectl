/*
 * UserService+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/26.
 */

import Foundation

import Email
import OfficeModelCore

import ServiceKit



extension UserService {
	
	public func taggedID(fromUserID userID: UserType.IDType) -> TaggedID {
		return TaggedID(tag: id, id: string(fromUserID: userID))
	}
	
	public func taggedID(fromPersistentUserID pID: UserType.PersistentIDType) -> TaggedID {
		return TaggedID(tag: id, id: string(fromPersistentUserID: pID))
	}
	
	public func wrappedUser(fromUser user: UserType) throws -> UserWrapper {
		var ret = UserWrapper(
			id: taggedID(fromUserID: user.id),
			persistentID: user.persistentID.flatMap(taggedID(fromPersistentUserID:)),
			underlyingUser: try json(fromUser: user)
		)
		ret.copyStandardNonIDProperties(fromUser: user)
		return ret
	}
	
	public func logicalUser(fromWrappedUser user: UserWrapper, hints: [UserProperty: String?]) throws -> UserType {
		var ret = try logicalUser(fromWrappedUser: user)
		applyHints(hints, toUser: &ret, allowUserIDChange: false)
		return ret
	}
	
//	public func logicalUser(fromEmail email: Email, hints: [UserProperty: String?] = [:], servicesProvider: OfficeKitServiceProvider) throws -> UserType {
//		return try logicalUser(fromEmail: email, hints: hints, emailService: servicesProvider.getUserDirectoryService(id: nil))
//	}
//
//	public func logicalUser(fromEmail email: Email, hints: [UserProperty: String?] = [:], emailService: EmailService) throws -> UserType {
//		let genericUser = try emailService.wrappedUser(fromUser: emailService.logicalUser(fromUserID: email))
//		return try logicalUser(fromWrappedUser: genericUser, hints: hints)
//	}
	
	public func logicalUser(fromUserID userID: UserType.IDType, hints: [UserProperty: String?] = [:]) throws -> UserType {
		let user = UserWrapper(id: taggedID(fromUserID: userID))
		return try logicalUser(fromWrappedUser: user, hints: hints)
	}
	
	public func logicalUser<OtherServiceType : UserService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [UserProperty: String?] = [:]) throws -> UserType {
		return try logicalUser(fromWrappedUser: service.wrappedUser(fromUser: user), hints: hints)
	}
	
	public func existingUser<OtherServiceType : UserService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [UserProperty: String?] = [:], propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> UserType? {
		let foreignGenericUser = try service.wrappedUser(fromUser: user)
		let nativeLogicalUser = try logicalUser(fromWrappedUser: foreignGenericUser, hints: hints)
		return try await existingUser(fromUserID: nativeLogicalUser.id, propertiesToFetch: propertiesToFetch, using: services)
	}
	
	public func existingUser<UserAndServiceType : UserAndService>(fromUserAndService userAndService: UserAndServiceType, hints: [UserProperty: String?] = [:], propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> UserType? {
		let foreignGenericUser = try userAndService.service.wrappedUser(fromUser: userAndService.user)
		let nativeLogicalUser = try logicalUser(fromWrappedUser: foreignGenericUser, hints: hints)
		return try await existingUser(fromUserID: nativeLogicalUser.id, propertiesToFetch: propertiesToFetch, using: services)
	}
	
}
