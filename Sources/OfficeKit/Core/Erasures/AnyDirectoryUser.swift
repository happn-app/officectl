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
 *       erasureForId = { AnyHashable(user.id) }
 *       erasureForEmail = { user.email }
 *       ...
 *    }
 *    public var id: AnyHashable {
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
	
	var id: AnyHashable {get}
	
	var emails: RemoteProperty<[Email]> {get}
	
	var firstName: RemoteProperty<String?> {get}
	var lastName: RemoteProperty<String?> {get}
	var nickname: RemoteProperty<String?> {get}
	
}

private struct ConcreteUserBox<Base : DirectoryUser> : DirectoryUserBox {
	
	let originalUser: Base
	
	var id: AnyHashable {
		return AnyHashable(originalUser.id)
	}
	
	var emails: RemoteProperty<[Email]> {
		return originalUser.emails
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
	
	public typealias IdType = AnyHashable
	
	public init<U : DirectoryUser>(_ user: U) {
		box = ConcreteUserBox(originalUser: user)
	}
	
	public func unwrapped<UserType : DirectoryUser>() -> UserType? {
		return (box as? ConcreteUserBox<UserType>)?.originalUser ?? (box as? ConcreteUserBox<AnyDirectoryUser>)?.originalUser.unwrapped()
	}
	
	public var id: AnyHashable {
		return box.id
	}
	
	public var emails: RemoteProperty<[Email]> {
		return box.emails
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
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	public static func ==(lhs: AnyDirectoryUser, rhs: AnyDirectoryUser) -> Bool {
		return lhs.id == rhs.id
	}
	
	private let box: DirectoryUserBox
	
}


public extension DirectoryUser {
	
	func erased() -> AnyDirectoryUser {
		if let erased = self as? AnyDirectoryUser {
			return erased
		}
		
		return AnyDirectoryUser(self)
	}
	
}
