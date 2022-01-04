/*
 * AnyID.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/30.
 */

import Foundation



private protocol IDBox {
	
	func unbox<T : Hashable>() -> T?
	
	func hash(into hasher: inout Hasher)
	func isEqual(_ other: IDBox) -> Bool
	
}

private struct ConcreteIDBox<Base : Hashable> : IDBox {
	
	let originalUserID: Base
	
	func unbox<T>() -> T? where T : Hashable {
		return originalUserID as? T
	}
	
	func hash(into hasher: inout Hasher) {
		originalUserID.hash(into: &hasher)
	}
	
	func isEqual(_ other: IDBox) -> Bool {
		guard let otherAsBase: Base = other.unbox() else {return false}
		return otherAsBase == originalUserID
	}
	
}


public class AnyID : Hashable {
	
	init<T : Hashable>(_ object: T) {
		box = ConcreteIDBox(originalUserID: object)
	}
	
	public func hash(into hasher: inout Hasher) {
		box.hash(into: &hasher)
	}
	
	public static func ==(_ lhs: AnyID, _ rhs: AnyID) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	fileprivate let box: IDBox
	
}


extension Hashable {
	
	public func erase() -> AnyID {
		if let erased = self as? AnyID {
			return erased
		}
		
		return AnyID(self)
	}
	
	public func unbox<UserIDType : Hashable>() -> UserIDType? {
		guard let anyUserID = self as? AnyID else {
			/* Nothing to unbox, just return self */
			return self as? UserIDType
		}
		
		return (anyUserID.box as? ConcreteIDBox<UserIDType>)?.originalUserID ?? (anyUserID.box as? ConcreteIDBox<AnyID>)?.originalUserID.unbox()
	}
	
}
