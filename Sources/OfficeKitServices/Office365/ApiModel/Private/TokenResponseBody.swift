/*
 * TokenResponseBody.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation



struct TokenResponseBody : Sendable, Decodable {
	
	let tokenType: String
	let accessToken: String
	let expiresIn: Int
	let extExpiresIn: Int
	
	private enum CodingKeys : String, CodingKey {
		case tokenType = "token_type", accessToken = "access_token", expiresIn = "expires_in", extExpiresIn = "ext_expires_in"
	}
	
}
