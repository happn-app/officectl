/*
 * TaggedId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



public struct TaggedId {
	
	public let tag: String
	public let id: String
	
	public init(tag t: String, id i: String) {
		tag = t
		id = i
	}
	
	public init(string: String) throws {
		let split = string.split(separator: ":", omittingEmptySubsequences: false)
		
		tag = String(split[0]) /* We do not omit empty subsequences, thus we know there will be at min 1 elmt in the resulting array */
		id = split.dropFirst().joined(separator: ":")
		
		guard !id.isEmpty else {
			throw InvalidArgumentError(message: "Got a TaggedId whose id part is empty. This is invalid.")
		}
	}
	
	public var stringValue: String {
		return tag + ":" + id
	}
	
}


extension TaggedId : Hashable {
}


extension TaggedId : CustomStringConvertible {
	
	public var description: String {
		return stringValue
	}
	
}


extension TaggedId : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(string: container.decode(String.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(stringValue)
	}
	
}
