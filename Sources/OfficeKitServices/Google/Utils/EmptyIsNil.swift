/*
 * HappnBirthDateWrapper.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/20.
 */

import Foundation



extension EmptyIsNil : Sendable where Wrapped : Sendable {}
extension EmptyIsNil : Hashable where Wrapped : Hashable {}
extension EmptyIsNil : Equatable where Wrapped : Equatable {}

@propertyWrapper
public struct EmptyIsNil<Wrapped : Codable> : Codable {
	
	public var wrappedValue: Wrapped?
	
	public init(wrappedValue: Wrapped?) {
		self.wrappedValue = wrappedValue
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let str = try container.decode(String.self)
		if str.isEmpty {wrappedValue = nil}
		else           {wrappedValue = try Wrapped(from: decoder)}
	}
	
	public func encode(to encoder: Encoder) throws {
		guard let wrappedValue else {
			var container = encoder.singleValueContainer()
			try container.encode("")
			return
		}
		try wrappedValue.encode(to: encoder)
	}
	
}


extension KeyedDecodingContainer {
	
	public func decode<T>(_ type: EmptyIsNil<T>.Type, forKey key: Key) throws -> EmptyIsNil<T> {
		return try decodeIfPresent(EmptyIsNil.self, forKey: key) ?? EmptyIsNil(wrappedValue: nil)
	}
	
}
