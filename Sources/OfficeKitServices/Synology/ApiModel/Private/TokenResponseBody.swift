/*
 * TokenResponseBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct TokenResponseBody : Sendable, Decodable {
	
	let sessionID: String
	let deviceID: String
	let csrfToken: String?
	
	private enum CodingKeys : String, CodingKey {
		case sessionID = "sid", deviceID = "did", csrfToken = "synotoken"
	}
	
}
