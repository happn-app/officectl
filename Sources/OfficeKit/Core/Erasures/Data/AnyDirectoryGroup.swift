/*
 * AnyDirectoryGroup.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/09/2019.
 */

import Foundation

import Email



private protocol DirectoryGroupBox {
	
	var groupId: AnyId {get}
	var persistentId: RemoteProperty<AnyId> {get}
	
	var identifyingEmail: RemoteProperty<Email?> {get}
	
	var name: RemoteProperty<String> {get}
	var description: RemoteProperty<String> {get}
	
}

private struct ConcreteDirectoryBox<Base : DirectoryGroup> : DirectoryGroupBox {
	
	let originalGroup: Base
	
	var groupId: AnyId {
		return AnyId(originalGroup.groupId)
	}
	
	var persistentId: RemoteProperty<AnyId> {
		return originalGroup.persistentId.map{ AnyId($0) }
	}
	
	var identifyingEmail: RemoteProperty<Email?> {
		return originalGroup.identifyingEmail
	}
	
	var name: RemoteProperty<String> {
		return originalGroup.name
	}
	
	var description: RemoteProperty<String> {
		return originalGroup.description
	}
	
}

public struct AnyDirectoryGroup : DirectoryGroup {
	
	public typealias IdType = AnyId
	public typealias PersistentIdType = AnyId
	
	public init<G : DirectoryGroup>(_ group: G) {
		box = ConcreteDirectoryBox(originalGroup: group)
	}
	
	public var groupId: AnyId {
		return box.groupId
	}
	
	public var persistentId: RemoteProperty<AnyId> {
		return box.persistentId
	}
	
	public var identifyingEmail: RemoteProperty<Email?> {
		return box.identifyingEmail
	}
	
	public var name: RemoteProperty<String> {
		return box.name
	}
	
	public var description: RemoteProperty<String> {
		return box.description
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
