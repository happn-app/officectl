/*
 * GoogleUsersList.swift
 * ghapp
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



struct GoogleUsersList : Codable {
	
	enum Kind: String, Codable {
		
		case user = "admin#directory#users"
		
	}
	
	var kind: Kind
	var etag: String
	
	var users: [GoogleUser]
	var nextPageToken: String?
	
}
