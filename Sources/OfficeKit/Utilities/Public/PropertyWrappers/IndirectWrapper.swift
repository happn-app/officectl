/*
 * IndirectWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation



extension Indirect : @unchecked Sendable where Wrapped : Sendable {}
@propertyWrapper public final class Indirect<Wrapped> {
	
	public var wrappedValue: Wrapped
	
	public init(wrappedValue: Wrapped) {
		self.wrappedValue = wrappedValue
	}
	
}


extension Indirect : Hashable where Wrapped : Hashable {
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(wrappedValue)
	}
	
}


extension Indirect : Equatable where Wrapped : Equatable {
	
	public static func ==(lhs: Indirect<Wrapped>, rhs: Indirect<Wrapped>) -> Bool {
		return lhs.wrappedValue == rhs.wrappedValue
	}
	
}


extension Indirect : Decodable where Wrapped : Decodable {
	
	public convenience init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(wrappedValue: try container.decode(Wrapped.self))
	}
	
}


extension Indirect : Encodable where Wrapped : Encodable {
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(wrappedValue)
	}
	
}


extension KeyedDecodingContainer {
	
	public func decode<T : Decodable>(_ type: Indirect<T?>.Type, forKey key: Key) throws -> Indirect<T?> {
		return try decodeIfPresent(Indirect<T?>.self, forKey: key) ?? Indirect<T?>(wrappedValue: nil)
	}
	
}
