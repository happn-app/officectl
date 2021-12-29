/*
 * AnyDirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/01.
 */

import Foundation

import Email



/* Note: Cannot erase with this erasure type
 *
 * public struct AnyDirectoryUser : DirectoryUser {
 *    public init<U : DirectoryUser>(_ user: U) {
 *       erasureForId = { AnyId(user.id) }
 *       erasureForEmail = { user.email }
 *       ...
 *    }
 *    public var id: AnyId {
 *       return erasureForId()
 *    }
 *    public var email: RemoteProperty<Email?> {
 *       return erasureForEmail()
 *    }
 *    ...
 * }
 *
 * because if we do, we cannot unbox to the original user… */

private protocol DirectoryUserBox {
	
	var userId: AnyId {get}
	var persistentId: RemoteProperty<AnyId> {get}
	
	var identifyingEmail: RemoteProperty<Email?> {get}
	var otherEmails: RemoteProperty<[Email]> {get}
	
	var firstName: RemoteProperty<String?> {get}
	var lastName: RemoteProperty<String?> {get}
	var nickname: RemoteProperty<String?> {get}
	
}

private struct ConcreteUserBox<Base : DirectoryUser> : DirectoryUserBox {
	
	let originalUser: Base
	
	var userId: AnyId {
		return AnyId(originalUser.userId)
	}
	
	var persistentId: RemoteProperty<AnyId> {
		return originalUser.persistentId.map{ AnyId($0) }
	}
	
	var identifyingEmail: RemoteProperty<Email?> {
		return originalUser.identifyingEmail
	}
	
	var otherEmails: RemoteProperty<[Email]> {
		return originalUser.otherEmails
	}
	
	var firstName: RemoteProperty<String?> {
		return originalUser.firstName
	}
	var lastName: RemoteProperty<String?> {
		return originalUser.lastName
	}
	var nickname: RemoteProperty<String?> {
		return originalUser.nickname
	}
	
}

public struct AnyDirectoryUser : DirectoryUser {
	
	public typealias IdType = AnyId
	public typealias PersistentIdType = AnyId
	
	public init<U : DirectoryUser>(_ user: U) {
		box = ConcreteUserBox(originalUser: user)
	}
	
	public var userId: AnyId {
		return box.userId
	}
	
	public var persistentId: RemoteProperty<AnyId> {
		return box.persistentId
	}
	
	public var identifyingEmail: RemoteProperty<Email?> {
		return box.identifyingEmail
	}
	
	public var otherEmails: RemoteProperty<[Email]> {
		return box.otherEmails
	}
	
	public var firstName: RemoteProperty<String?> {
		return box.firstName
	}
	public var lastName: RemoteProperty<String?> {
		return box.lastName
	}
	public var nickname: RemoteProperty<String?> {
		return box.nickname
	}
	
	fileprivate let box: DirectoryUserBox
	
}


extension DirectoryUser {
	
	public func erase() -> AnyDirectoryUser {
		if let erased = self as? AnyDirectoryUser {
			return erased
		}
		
		return AnyDirectoryUser(self)
	}
	
	public func unbox<UserType : DirectoryUser>() -> UserType? {
		guard let anyUser = self as? AnyDirectoryUser else {
			/* Nothing to unbox, just return self */
			return self as? UserType
		}
		
		return (anyUser.box as? ConcreteUserBox<UserType>)?.originalUser ?? (anyUser.box as? ConcreteUserBox<AnyDirectoryUser>)?.originalUser.unbox()
	}
	
}
