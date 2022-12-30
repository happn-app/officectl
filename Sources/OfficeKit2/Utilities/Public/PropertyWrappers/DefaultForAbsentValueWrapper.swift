/*
 * DefaultForAbsentValueWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/30.
 * 
 */

import Foundation



extension DefaultForAbsentValue : Sendable where Wrapped : Sendable {}
extension DefaultForAbsentValue : Hashable where Wrapped : Hashable {}
extension DefaultForAbsentValue : Equatable where Wrapped : Equatable {}

@propertyWrapper
public struct DefaultForAbsentValue<DefaultValueProvider : OfficeKit2.DefaultValueProvider> {
	
	public typealias Wrapped = DefaultValueProvider.DefaultValue
	
	public var wrappedValue: Wrapped {
		get {projectedValue ?? DefaultValueProvider.defaultValue}
		set {projectedValue = newValue}
	}
	
	public private(set) var projectedValue: Wrapped?
	
	public init(value: Wrapped? = nil) {
		self.projectedValue = value
	}
	
}

public protocol DefaultValueProvider {
	associatedtype DefaultValue
	static var defaultValue: DefaultValue {get}
}


extension DefaultForAbsentValue : Decodable where Wrapped : Decodable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.projectedValue = try container.decode(Wrapped.self)
	}
	
}


extension DefaultForAbsentValue : Encodable where Wrapped : Encodable {
	
	public func encode(to encoder: Encoder) throws {
		if let projectedValue {
			var container = encoder.singleValueContainer()
			try container.encode(projectedValue)
		}
	}
	
}


extension KeyedDecodingContainer {
	
	public func decode<DefaultValueProvider : OfficeKit2.DefaultValueProvider>(_ type: DefaultForAbsentValue<DefaultValueProvider>.Type, forKey key: Key) throws -> DefaultForAbsentValue<DefaultValueProvider>
	where DefaultValueProvider.DefaultValue : Codable {
		return try decodeIfPresent(DefaultForAbsentValue.self, forKey: key) ?? DefaultForAbsentValue()
	}
	
}
