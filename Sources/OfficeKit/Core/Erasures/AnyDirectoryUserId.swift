/*
 * AnyDirectoryUserId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 30/08/2019.
 */

import Foundation



private protocol DirectoryUserIdBox {
	
	func unbox<T : Hashable>() -> T?
	
	func hash(into hasher: inout Hasher)
	func isEqual(_ other: DirectoryUserIdBox) -> Bool
	
}

private struct ConcreteDirectoryUserIdBox<Base : Hashable> : DirectoryUserIdBox {
	
	let originalUserId: Base
	
	func unbox<T>() -> T? where T : Hashable {
		return originalUserId as? T
	}
	
	func hash(into hasher: inout Hasher) {
		originalUserId.hash(into: &hasher)
	}
	
	func isEqual(_ other: DirectoryUserIdBox) -> Bool {
		guard let otherAsBase: Base = other.unbox() else {return false}
		return otherAsBase == originalUserId
	}
	
}

public class AnyDirectoryUserId : Hashable {
	
	init<T : Hashable>(_ object: T) {
		box = ConcreteDirectoryUserIdBox(originalUserId: object)
	}
	
	public func hash(into hasher: inout Hasher) {
		box.hash(into: &hasher)
	}
	
	public static func ==(_ lhs: AnyDirectoryUserId, _ rhs: AnyDirectoryUserId) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	fileprivate let box: DirectoryUserIdBox
	
}

extension Hashable {
	
	public func erased() -> AnyDirectoryUserId {
		if let erased = self as? AnyDirectoryUserId {
			return erased
		}
		
		return AnyDirectoryUserId(self)
	}
	
	public func unboxed<UserIdType : Hashable>() -> UserIdType? {
		guard let anyUserId = self as? AnyDirectoryUserId else {
			/* Nothing to unbox, just return self */
			return self as? UserIdType
		}
		
		return (anyUserId.box as? ConcreteDirectoryUserIdBox<UserIdType>)?.originalUserId ?? (anyUserId.box as? ConcreteDirectoryUserIdBox<AnyDirectoryUserId>)?.originalUserId.unboxed()
	}
	
}
