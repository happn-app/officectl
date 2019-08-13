/*
 * TaggedId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



public struct TaggedId {
	
	public var tag: String
	public var id: String
	
	public init(string: String) {
		let split = string.split(separator: ":", omittingEmptySubsequences: false)
		
		let t = String(split[0]) /* We do not omit empty subsequences, thus we know there will be at min 1 elmt in the resulting array */
		let i = split.dropFirst().joined(separator: ":")
		
		self.init(tag: t, id: i)
	}
	
	public init(tag t: String, id i: String) {
		if i.isEmpty       {OfficeKitConfig.logger?.warning("Initing a TaggedId with an empty id value.")}
		if t.contains(":") {OfficeKitConfig.logger?.error("Initing a TaggedId with a tag that contains a colon (tag=\(t)).")}
		
		tag = t
		id = i
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


extension TaggedId : RawRepresentable {
	
	public typealias RawValue = String
	
	public init?(rawValue: String) {
		self.init(string: rawValue)
	}
	
	public var rawValue: String {
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
