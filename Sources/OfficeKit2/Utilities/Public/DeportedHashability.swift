/*
 * DeportedHashability.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/24.
 */

import Foundation



/**
 The given value’s hashability is deported to the given id.
 Any time two DeportedHashability are compared, only the id is compared.
 For the hash, only the id is hashed.
 Any time the value is updated, the id must be updated with it (the API of DeportedHashability guarantees you cannot update one with the other). */
public struct DeportedHashability<ValueType : Sendable, IDType : Hashable & Sendable> : Sendable, Hashable {
	
	public private(set) var id: IDType
	public private(set) var value: ValueType
	
	public init(value: ValueType, valueID: IDType) {
		self.id = valueID
		self.value = value
	}
	
	public mutating func set(value: ValueType, valueID: IDType) {
		self.id = valueID
		self.value = value
	}
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.id == rhs.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
}
