/*
 * Email+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/20.
 */

import Foundation

import Email



extension Email : MightHaveEmail {
	
	public var email: Email? {
		return self
	}
	
}


public extension Email {
	
	init(_ e: Email, newLocalPart: String? = nil, newDomainPart: String? = nil) {
		/* While Email does not support something better, we do this. */
		self.init(rawValue: "\(newLocalPart ?? e.localPart)@\(newDomainPart ?? e.domainPart)")!
	}
	
	/** Key of the alias map is a domain alias, value is the actual domain. */
	func primaryDomainVariant(aliasMap: [String: String]?) -> Email {
		if let primary = aliasMap?[domainPart] {
			return Email(self, newDomainPart: primary)
		}
		return self
	}
	
	/** Key of the alias map is a domain alias, value is the actual domain. */
	func allDomainVariants(aliasMap: [String: String]?) -> Set<Email> {
		guard let aliasMap else {return [self]}
		let primaryDomain = aliasMap[domainPart] ?? domainPart
		let variants = aliasMap.filter{ $0.value == primaryDomain }.keys
		return Set(variants.map{ Email(self, newDomainPart: $0) }).union([Email(self, newDomainPart: primaryDomain)])
	}
	
}
