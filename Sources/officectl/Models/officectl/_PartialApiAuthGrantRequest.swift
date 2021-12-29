/*
 * _PartialApiAuthGrantRequest.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/29.
 */

import Foundation



struct _PartialApiAuthGrantRequest : Decodable {
	
	var grantType: String
	
	/* Unless I’m mistaken all OAuth2 grant requests can have a scope. */
	var scope: String?
	
	/* Unless I’m mistaken all OAuth2 grant requests can have a client id/client secret. */
	var clientId: String?
	var clientSecret: String?
	
	private enum CodingKeys : String, CodingKey {
		case grantType = "grant_type"
		
		case scope
		
		case clientId = "client_id"
		case clientSecret = "client_secret"
	}
	
}
