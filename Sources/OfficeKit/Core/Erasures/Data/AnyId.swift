/*
 * AnyId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/30.
 */

import Foundation



private protocol IdBox {
	
	func unbox<T : Hashable>() -> T?
	
	func hash(into hasher: inout Hasher)
	func isEqual(_ other: IdBox) -> Bool
	
}

private struct ConcreteIdBox<Base : Hashable> : IdBox {
	
	let originalUserId: Base
	
	func unbox<T>() -> T? where T : Hashable {
		return originalUserId as? T
	}
	
	func hash(into hasher: inout Hasher) {
		originalUserId.hash(into: &hasher)
	}
	
	func isEqual(_ other: IdBox) -> Bool {
		guard let otherAsBase: Base = other.unbox() else {return false}
		return otherAsBase == originalUserId
	}
	
}

public class AnyId : Hashable {
	
	init<T : Hashable>(_ object: T) {
		box = ConcreteIdBox(originalUserId: object)
	}
	
	public func hash(into hasher: inout Hasher) {
		box.hash(into: &hasher)
	}
	
	public static func ==(_ lhs: AnyId, _ rhs: AnyId) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	fileprivate let box: IdBox
	
}

extension Hashable {
	
	public func erase() -> AnyId {
		if let erased = self as? AnyId {
			return erased
		}
		
		return AnyId(self)
	}
	
	public func unbox<UserIdType : Hashable>() -> UserIdType? {
		guard let anyUserId = self as? AnyId else {
			/* Nothing to unbox, just return self */
			return self as? UserIdType
		}
		
		return (anyUserId.box as? ConcreteIdBox<UserIdType>)?.originalUserId ?? (anyUserId.box as? ConcreteIdBox<AnyId>)?.originalUserId.unbox()
	}
	
}
