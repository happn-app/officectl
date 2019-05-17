/*
 * Email.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation

import EmailValidator



public struct Email {
	
	public var username: String
	public var domain: String
	
	public var stringValue: String {
		return username + "@" + domain
	}
	
	public init?(string: String) {
		#warning("TODO: Proper mail validation")
		/* For the time being we only do this validation. In a future time,
		 * EmailValidator will return the full, parsed email (getting rid of
		 * comments, etc.). */
		guard EmailValidator(string: string).evaluateEmail().category.value < EmailValidator.ValidationCategory.err.value else {
			return nil
		}
		let components = string.split(separator: "@")
		guard components.count == 2 else {return nil}
		
		self.init(username: String(components[0]), domain: String(components[1]))
	}
	
	public init?(username un: String, domain d: String) {
		#warning("TODO: Proper mail validation")
		guard !un.isEmpty, !d.isEmpty else {return nil}
		username = un
		domain = d
	}
	
	init(_ e: Email, newUsername: String? = nil, newDomain: String? = nil) {
		username = newUsername ?? e.username
		domain = newDomain ?? e.domain
	}
	
	public func primaryDomainVariant(aliasMap: [String: String]) -> Email {
		if let primary = aliasMap[domain] {
			return Email(self, newDomain: primary)
		}
		return self
	}
	
}


extension Email : Hashable {
}


extension Email : Codable {
	
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


extension Email : CustomStringConvertible {
	
	public var description: String {
		return stringValue
	}
	
}



public extension LDAPDistinguishedName {
	
	/** Create a DN from an email.
	
	Result will be of the form:
	
	    uid=username,MIDDLE_DN,dc=subdomain1,dc=subdomain2...
	
	Example: For `francois.lamboley@example.com`, with middle dn `ou=people`,
	you’ll get:
	
	    uid=francois.lamboley,ou=people,dc=example,dc=com */
	@available(*, deprecated, message: "This method assumes the DN will be of the form uid=username,MIDDLE_DN,dc=subdomain1,dc=subdomain2... which is a stretch.")
	init(email: Email, middleDN: LDAPDistinguishedName) {
		values = [(key: "uid", value: email.username)] + middleDN.values + email.domain.split(separator: ".").map{
			(key: "dc", value: String($0))
		}
	}
	
}
