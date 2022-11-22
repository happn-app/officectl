/*
 * GrantRequestBody.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/22.
 */

import Foundation



internal struct GrantRequestBody : Encodable {
	
	var action = "grant"
	var userID: String
	var adminPassword: String
	
	private enum CodingKeys : String, CodingKey {
		case action = "_action", userID = "user_id", adminPassword = "password"
	}
	
}
