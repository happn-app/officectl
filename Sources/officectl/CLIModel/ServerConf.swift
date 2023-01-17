/*
 * ServerConf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

@preconcurrency import JWT



struct ServerConf : Decodable, Sendable {
	
	var mainJWTKey: JWKIdentifier
	/* We do not set JWKIdentifier keys for this dictionary to simplify decoding. */
	var jwtSecrets: [String/*JWKIdentifier*/: String]
	
	var hostname: String?
	var port: Int?
	
	enum CodingKeys : String, CodingKey {
		case mainJWTKey = "main_jwt_key"
		case jwtSecrets = "jwt_secrets"
		
		case hostname
		case port
	}
	
}
