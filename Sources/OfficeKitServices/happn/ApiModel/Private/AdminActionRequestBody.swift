/*
 * AdminActionRequestBody.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/22.
 */

import Foundation



internal struct AdminActionRequestBody : Sendable, Encodable {
	
	var action: String
	var userID: String
	var adminPassword: String
	
	private enum CodingKeys : String, CodingKey {
		case action = "_action", userID = "user_id", adminPassword = "password"
	}
	
}
