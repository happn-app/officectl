/*
 * AnyDirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/01.
 */

import Foundation

import Email

import OfficeModel



/* Note: Cannot erase with this erasure type
 *
 * public struct AnyDirectoryUser : DirectoryUser {
 *    public init<U : DirectoryUser>(_ user: U) {
 *       erasureForID = { AnyID(user.id) }
 *       erasureForEmail = { user.email }
 *       ...
 *    }
 *    public var id: AnyID {
 *       return erasureForID()
 *    }
 *    public var email: RemoteProperty<Email?> {
 *       return erasureForEmail()
 *    }
 *    ...
 * }
 *
 * because if we do, we cannot unbox to the original user… */

private protocol DirectoryUserBox : Sendable {
	
	var userID: AnyID {get}
	var remotePersistentID: RemoteProperty<AnyID> {get}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {get}
	var remoteOtherEmails: RemoteProperty<[Email]> {get}
	
	var remoteFirstName: RemoteProperty<String?> {get}
	var remoteLastName: RemoteProperty<String?> {get}
	var remoteNickname: RemoteProperty<String?> {get}
	
}

private struct ConcreteUserBox<Base : DirectoryUser> : DirectoryUserBox {
	
	let originalUser: Base
	
	var userID: AnyID {
		return AnyID(originalUser.userID)
	}
	
	var remotePersistentID: RemoteProperty<AnyID> {
		return originalUser.remotePersistentID.map{ AnyID($0) }
	}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return originalUser.remoteIdentifyingEmail
	}
	
	var remoteOtherEmails: RemoteProperty<[Email]> {
		return originalUser.remoteOtherEmails
	}
	
	var remoteFirstName: RemoteProperty<String?> {
		return originalUser.remoteFirstName
	}
	var remoteLastName: RemoteProperty<String?> {
		return originalUser.remoteLastName
	}
	var remoteNickname: RemoteProperty<String?> {
		return originalUser.remoteNickname
	}
	
}

public struct AnyDirectoryUser : DirectoryUser {
	
	public typealias IDType = AnyID
	public typealias PersistentIDType = AnyID
	
	public init<U : DirectoryUser>(_ user: U) {
		box = ConcreteUserBox(originalUser: user)
	}
	
	public var userID: AnyID {
		return box.userID
	}
	
	public var remotePersistentID: RemoteProperty<AnyID> {
		return box.remotePersistentID
	}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return box.remoteIdentifyingEmail
	}
	
	public var remoteOtherEmails: RemoteProperty<[Email]> {
		return box.remoteOtherEmails
	}
	
	public var remoteFirstName: RemoteProperty<String?> {
		return box.remoteFirstName
	}
	public var remoteLastName: RemoteProperty<String?> {
		return box.remoteLastName
	}
	public var remoteNickname: RemoteProperty<String?> {
		return box.remoteNickname
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
