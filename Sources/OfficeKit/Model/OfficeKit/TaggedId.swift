/*
 * TaggedId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



public struct TaggedId : ExpressibleByStringLiteral {
	
	public typealias StringLiteralType = String
	
	let tag: String
	let id: String
	
	public init(tag t: String, id i: String) {
		tag = t
		id = i
	}
	
	public init(stringLiteral string: String) {
		let split = string.split(separator: ":", omittingEmptySubsequences: false)
		
		tag = String(split[0]) /* We do not omit empty subsequences, thus we know there will be at min 1 elmt in the resulting array */
		id = split.dropFirst().joined(separator: ":")
		
		if id.isEmpty {
			#warning("print is bad…")
			print("*** WARNING: Inited a tagged id with \"\(string)\" which resulted in an empty id. This is probably not what you want.")
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
		try self.init(stringLiteral: container.decode(String.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(stringValue)
	}
	
}
