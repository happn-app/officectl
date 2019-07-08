/*
 * Property.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public enum RemoteProperty<T> {
	
	case fetched(T)
	case unfetched
	case unsupported
	
	func erased() -> RemoteProperty<Any?> {
		if let p = self as? RemoteProperty<Any?> {
			return p
		}
		
		switch self {
		case .unfetched:      return .unfetched
		case .unsupported:    return .unsupported
		case .fetched(let v): return .fetched(v)
		}
	}
	
	public var value: T? {
		switch self {
		case .fetched(let v):          return v
		case .unfetched, .unsupported: return nil
		}
	}
	
	public func map<U>(to type: U.Type = U.self, _ callback: (T) throws -> U) rethrows -> RemoteProperty<U> {
		switch self {
		case .unfetched:      return .unfetched
		case .unsupported:    return .unsupported
		case .fetched(let v): return try .fetched(callback(v))
		}
	}
	
}


extension RemoteProperty : Codable where T : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .fetched(container.decode(T.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		switch self {
		case .fetched(let v):
			var container = encoder.singleValueContainer()
			try container.encode(v)

		case .unfetched, .unsupported:
			(/*nop*/)
		}
	}
	
}


extension RemoteProperty : Equatable where T : Equatable {
	
	public static func ==(_ prop1: RemoteProperty<T>, _ prop2: RemoteProperty<T>) -> Bool {
		switch (prop1, prop2) {
		case (.fetched(let v1), .fetched(let v2)):                   return v1 == v2
		case (.unfetched, .unfetched), (.unsupported, .unsupported): return true
		case (.fetched, _), (.unfetched, _), (.unsupported, _):      return false
		}
	}
	
}


extension RemoteProperty : Hashable where T : Hashable {
	
	public func hash(into hasher: inout Hasher) {
		switch self {
		case .fetched(let v): hasher.combine(0); hasher.combine(v)
		case .unfetched:      hasher.combine(1)
		case .unsupported:    hasher.combine(2)
		}
	}
	
}
