/*
 * UsersListResponseBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct UsersListResponseBody : Sendable, Decodable {
	
	var offset: Int
	var total: Int
	
	var users: [SynologyUser]
	
	enum CodingKeys : String, CodingKey {
		case offset
		case total
		
		case users
	}
	
}
