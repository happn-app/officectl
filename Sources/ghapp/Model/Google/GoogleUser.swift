/*
 * GoogleUser.swift
 * ghapp
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



struct GoogleUser : Codable {
	
	enum Kind: String, Codable {
		
		case user = "admin#directory#user"
		
	}
	
	var kind: Kind
	var etag: String?
	
	var id: String
	var customerId: String
	
	var primaryEmail: String
	var aliases: [String]?
	var nonEditableAliases: [String]?
	var includeInGlobalAddressList: Bool
	
	var isAdmin: Bool
	var isDelegatedAdmin: Bool
	
	var lastLoginTime: Date?
	var creationTime: Date
	var agreedToTerms: Bool
	
	var suspended: Bool
	var changePasswordAtNextLogin: Bool
	
}
