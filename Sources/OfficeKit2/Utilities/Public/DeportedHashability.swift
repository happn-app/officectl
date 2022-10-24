/*
 * DeportedHashability.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/24.
 */

import Foundation



public struct DeportedHashability<ValueType : Sendable> : Sendable, Hashable {
	
	private let _id: AnySendableHashable
	public var id: AnyHashable {_id.val}
	public let value: ValueType
	
	public init<IDType : Sendable & Hashable>(id: IDType, value: ValueType) {
		self._id = .init(id)
		self.value = value
	}
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.id == rhs.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	/* Sendability of this struct is guaranteed by the init. */
	private struct AnySendableHashable : @unchecked Sendable, Hashable {
		
		init<T : Sendable & Hashable>(_ val: T) {
			self.val = val
		}
		
		let val: AnyHashable
		
	}
	
}
