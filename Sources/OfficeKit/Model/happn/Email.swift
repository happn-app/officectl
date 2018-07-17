/*
 * Email.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



public struct Email : Codable {
	
	public var username: String
	public var domain: String
	
	public var stringValue: String {
		return username + "@" + domain
	}
	
	public init?(string: String) {
		let components = string.split(separator: "@")
		guard components.count == 2 else {return nil}
		
		self.init(username: String(components[0]), domain: String(components[1]))
	}
	
	public init?(username un: String, domain d: String) {
		guard !un.isEmpty, !d.isEmpty else {return nil}
		username = un
		domain = d
	}
	
	init(_ e: Email) {
		username = e.username
		domain = e.domain
	}
	
	public init(from decoder: Decoder) throws {
		let value = try decoder.singleValueContainer()
		let emailString = try value.decode(String.self)
		guard let e = Email(string: emailString) else {throw EncodingError.invalidValue(emailString, EncodingError.Context(codingPath: [], debugDescription: "email is invalid"))}
		
		self.init(e)
	}
	
	public func encode(to encoder: Encoder) throws {
		var value = encoder.singleValueContainer()
		try value.encode(stringValue)
	}
	
}
