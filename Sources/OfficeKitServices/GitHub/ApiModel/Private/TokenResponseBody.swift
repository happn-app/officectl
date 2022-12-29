/*
 * TokenResponseBody.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation



struct TokenResponseBody : Codable {
	
	var token: String
	var expiresAt: Date
	
	private enum CodingKeys: String, CodingKey {
		
		case token
		case expiresAt = "expires_at"
		
	}
	
}
