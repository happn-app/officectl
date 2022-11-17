/*
 * TokenResponseBody.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/17.
 * 
 */

import Foundation



internal struct TokenResponseBody : Decodable {
	
	let scope: String
	let userID: String
	
	let accessToken: String
	let refreshToken: String
	
	let expiresIn: Int
	let errorCode: Int
	
	private enum CodingKeys : String, CodingKey {
		case scope, userID = "user_id"
		case accessToken = "access_token", refreshToken = "refresh_token"
		case expiresIn = "expires_in"
		case errorCode = "error_code"
	}
	
}
