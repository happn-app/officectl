/*
 * AnyDirectoryGroup.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/26.
 */

import Foundation

import Email

import OfficeModel



private protocol DirectoryGroupBox {
	
	var groupID: AnyID {get}
	var remotePersistentID: RemoteProperty<AnyID> {get}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {get}
	
	var remoteName: RemoteProperty<String> {get}
	var remoteDescription: RemoteProperty<String> {get}
	
}


private struct ConcreteDirectoryBox<Base : DirectoryGroup> : DirectoryGroupBox {
	
	let originalGroup: Base
	
	var groupID: AnyID {
		return AnyID(originalGroup.groupID)
	}
	
	var remotePersistentID: RemoteProperty<AnyID> {
		return originalGroup.remotePersistentID.map{ AnyID($0) }
	}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return originalGroup.remoteIdentifyingEmail
	}
	
	var remoteName: RemoteProperty<String> {
		return originalGroup.remoteName
	}
	
	var remoteDescription: RemoteProperty<String> {
		return originalGroup.remoteDescription
	}
	
}

public struct AnyDirectoryGroup : DirectoryGroup {
	
	public typealias IDType = AnyID
	public typealias PersistentIDType = AnyID
	
	public init<G : DirectoryGroup>(_ group: G) {
		box = ConcreteDirectoryBox(originalGroup: group)
	}
	
	public var groupID: AnyID {
		return box.groupID
	}
	
	public var remotePersistentID: RemoteProperty<AnyID> {
		return box.remotePersistentID
	}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return box.remoteIdentifyingEmail
	}
	
	public var remoteName: RemoteProperty<String> {
		return box.remoteName
	}
	
	public var remoteDescription: RemoteProperty<String> {
		return box.remoteDescription
	}
	
	fileprivate let box: DirectoryGroupBox
	
}


extension DirectoryGroup {
	
	public func erase() -> AnyDirectoryGroup {
		if let erased = self as? AnyDirectoryGroup {
			return erased
		}
		
		return AnyDirectoryGroup(self)
	}
	
	public func unbox<GroupType : DirectoryGroup>() -> GroupType? {
		guard let anyGroup = self as? AnyDirectoryGroup else {
			/* Nothing to unbox, just return self */
			return self as? GroupType
		}
		
		return (anyGroup.box as? ConcreteDirectoryBox<GroupType>)?.originalGroup ?? (anyGroup.box as? ConcreteDirectoryBox<AnyDirectoryGroup>)?.originalGroup.unbox()
	}
	
}
