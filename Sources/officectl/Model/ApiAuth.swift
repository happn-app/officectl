/*
 * ApiAuth.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation



struct ApiAuth : Codable {
	
	var token: String
	var expirationDate: Date
	
	var isAdmin: Bool
	
	init(token t: String, expirationDate d: Date, isAdmin a: Bool) {
		token = t
		expirationDate = d
		isAdmin = a
	}
	
}
