/*
 * DeportedHashability.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/24.
 */

import Foundation



/**
 The given value’s hashability is deported to the given id.
 Any time two DeportedHashability are compared, the id only is compared.
 For the hash, only the id is hashed.
 Any time the value is updated, the id must be updated with it (the API of DeportedHashability guarantees it). */
public struct DeportedHashability<ValueType : Sendable> : Sendable, Hashable {
	
	private var _id: AnySendableHashable
	public var id: AnyHashable {_id.val}
	public private(set) var value: ValueType
	
	public init<IDType : Sendable & Hashable>(value: ValueType, valueID: IDType) {
		self.value = value
		self._id = .init(valueID)
	}
	
	public mutating func set<IDType : Sendable & Hashable>(value: ValueType, valueID: IDType) {
		self.value = value
		self._id = .init(valueID)
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
