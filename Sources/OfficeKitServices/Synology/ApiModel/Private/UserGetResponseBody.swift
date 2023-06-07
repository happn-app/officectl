/*
 * UserGetResponseBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct UserGetResponseBody : Sendable, Decodable {
	
	/* Yeah, it’s a f**ing list, but which contains only one element…
	 * Probably, the name field of the request can contain multiple elements, like for the deletion request. */
	var users: [SynologyUser]
	
	enum CodingKeys : String, CodingKey {
		case users
	}
	
}
