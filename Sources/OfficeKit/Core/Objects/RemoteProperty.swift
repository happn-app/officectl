/*
 * Property.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public enum RemoteProperty<T> {
	
	case set(T)
	case unset
	
	case unsupported
	
	func erase() -> RemoteProperty<Any?> {
		if let p = self as? RemoteProperty<Any?> {
			return p
		}
		
		switch self {
		case .unsupported: return .unsupported
		case .unset:       return .unset
		case .set(let v):  return .set(v)
		}
	}
	
	public var value: T? {
		switch self {
		case .set(let v):          return v
		case .unset, .unsupported: return nil
		}
	}
	
	public func map<U>(to type: U.Type = U.self, _ callback: (T) throws -> U) rethrows -> RemoteProperty<U> {
		switch self {
		case .unsupported: return .unsupported
		case .unset:       return .unset
		case .set(let v):  return try .set(callback(v))
		}
	}
	
}


extension RemoteProperty : Codable where T : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .set(container.decode(T.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		switch self {
		case .set(let v):
			var container = encoder.singleValueContainer()
			try container.encode(v)
			
		case .unset, .unsupported:
			fatalError("Unset or unsupported properties should not be encoded.")
		}
	}
	
}


extension KeyedEncodingContainer {
	
	mutating func encodeIfSet<T>(_ value: RemoteProperty<T>, forKey key: K) throws where T : Encodable {
		switch value {
		case .set(let v):          try encode(v, forKey: key)
		case .unset, .unsupported: (/*nop*/)
		}
	}
	
}


extension RemoteProperty : Equatable where T : Equatable {
	
	public static func ==(_ prop1: RemoteProperty<T>, _ prop2: RemoteProperty<T>) -> Bool {
		switch (prop1, prop2) {
		case (.set(let v1), .set(let v2)):                   return v1 == v2
		case (.unset, .unset), (.unsupported, .unsupported): return true
		case (.set, _), (.unset, _), (.unsupported, _):      return false
		}
	}
	
}


extension RemoteProperty : Hashable where T : Hashable {
	
	public func hash(into hasher: inout Hasher) {
		switch self {
		case .set(let v):  hasher.combine(0 as UInt8); hasher.combine(v)
		case .unset:       hasher.combine(1 as UInt8)
		case .unsupported: hasher.combine(2 as UInt8)
		}
	}
	
}
