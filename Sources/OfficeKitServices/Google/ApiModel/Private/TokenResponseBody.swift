/*
 * TokenResponseBody.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation



struct TokenResponseBody : Sendable, Decodable {
	
	let tokenType: String
	let accessToken: String
	let expiresIn: Int
	
	private enum CodingKeys : String, CodingKey {
		case tokenType = "token_type", accessToken = "access_token", expiresIn = "expires_in"
	}
	
}
