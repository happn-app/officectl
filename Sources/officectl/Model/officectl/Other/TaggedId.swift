/*
 * TaggedId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation

import OfficeKit



struct TaggedId {
	
	let tag: String
	let id: String
	
	init(string: String) throws {
		let split = string.split(separator: ":", omittingEmptySubsequences: false)
		
		let t = String(split[0]) /* We do not omit empty subsequences, thus we know there will be at min 1 elmt in the resulting array */
		let i = split.dropFirst().joined(separator: ":")
		
		try self.init(tag: t, id: i)
	}
	
	init(tag t: String, id i: String) throws {
		guard !i.isEmpty else {
			throw InvalidArgumentError(message: "The id of a TaggedId cannot be empty.")
		}
		guard !t.contains(":") else {
			throw InvalidArgumentError(message: "The tag of a TaggedId cannot contain a colon.")
		}
		
		tag = t
		id = i
	}
	
	var stringValue: String {
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
