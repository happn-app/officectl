/*
 * AnyDirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



/* Note: Cannot erase with this erasure type
 *
 * public struct AnyDirectoryUser : DirectoryUser {
 *    public init<U : DirectoryUser>(_ user: U) {
 *       erasureForId = { AnyDirectoryUserId(user.id) }
 *       erasureForEmail = { user.email }
 *       ...
 *    }
 *    public var id: AnyDirectoryUserId {
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
	
	var userId: AnyDirectoryUserId {get}
	var persistentId: RemoteProperty<AnyDirectoryUserId> {get}
	
	var identifyingEmail: RemoteProperty<Email?> {get}
	var otherEmails: RemoteProperty<[Email]> {get}
	
	var firstName: RemoteProperty<String?> {get}
	var lastName: RemoteProperty<String?> {get}
	var nickname: RemoteProperty<String?> {get}
	
}

private struct ConcreteUserBox<Base : DirectoryUser> : DirectoryUserBox {
	
	let originalUser: Base
	
	var userId: AnyDirectoryUserId {
		return AnyDirectoryUserId(originalUser.userId)
	}
	
	var persistentId: RemoteProperty<AnyDirectoryUserId> {
		switch originalUser.persistentId {
		case .set(let pId): return .set(AnyDirectoryUserId(pId))
		case .unset:        return .unset
		case .unsupported:  return .unsupported
		}
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
	
	public typealias IdType = AnyDirectoryUserId
	public typealias PersistentIdType = AnyDirectoryUserId
	
	public init<U : DirectoryUser>(_ user: U) {
		box = ConcreteUserBox(originalUser: user)
	}
	
	public var userId: AnyDirectoryUserId {
		return box.userId
	}
	
	public var persistentId: RemoteProperty<AnyDirectoryUserId> {
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
	
	public func erased() -> AnyDirectoryUser {
		if let erased = self as? AnyDirectoryUser {
			return erased
		}
		
		return AnyDirectoryUser(self)
	}
	
	public func unboxed<UserType : DirectoryUser>() -> UserType? {
		guard let anyUser = self as? AnyDirectoryUser else {
			/* Nothing to unbox, just return self */
			return self as? UserType
		}
		
		return (anyUser.box as? ConcreteUserBox<UserType>)?.originalUser ?? (anyUser.box as? ConcreteUserBox<AnyDirectoryUser>)?.originalUser.unboxed()
	}
	
}
