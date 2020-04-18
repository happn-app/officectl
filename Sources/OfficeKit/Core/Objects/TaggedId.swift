/*
 * TaggedId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



/**
A `TaggedId` is simple an id with a “namespace” (e.g. “email:a@example.com”, the
tag is “email”, the id is “a@example.com”).

A tag in a tagged id should not contain a colon as the string representation of
a tagged id is simply the tag followed by a colon and the id. No backslashing is
done on the tag, which means if a tag contains a colon, re-reading the TaggedId
from its string reprsentation will not return the same TaggedId!

- important: The `TaggedId` conforms to `LosslessStringConvertible`, which is
true as long as one does not set a tag with a colon in the TaggedId, otherwise
converting the TaggedId to a string and then back to a TaggedId will not produce
the same TaggedId. */
public struct TaggedId : LosslessStringConvertible {
	
	public var tag: String
	public var id: String
	
	public init?(_ str: String) {
		self.init(string: str)
	}
	
	public init(string: String) {
		let split = string.split(separator: ":", omittingEmptySubsequences: false)
		
		let t = String(split[0]) /* We do not omit empty subsequences, thus we know there will be at min 1 elmt in the resulting array */
		let i = split.dropFirst().joined(separator: ":")
		
		self.init(tag: t, id: i)
	}
	
	public init(tag t: String, id i: String) {
		if i.isEmpty       {OfficeKitConfig.logger?.warning("Initing a TaggedId with an empty id value.")}
		if t.contains(":") {OfficeKitConfig.logger?.error("Initing a TaggedId with a tag that contains a colon (tag=\(t)). Re-initing the tagged id from its string reprsentation will not produce the same tagged id!")}
		
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
