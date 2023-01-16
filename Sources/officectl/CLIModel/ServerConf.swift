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
	var jwtSecrets: [JWKIdentifier: String]
	
	var hostname: String?
	var port: Int?
	
	/* Custom init from decoder because Swift’s decoder is weird with String wrappers as keys of Dictionaries.
	 * We could use a [String: String] dictionary instead for jwtSecrets… */
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		self.mainJWTKey = try container.decode(JWKIdentifier.self, forKey: .mainJWTKey)
		let jwtSecretsString = try container.decode([String: String].self, forKey: .jwtSecrets)
		self.jwtSecrets = Dictionary(uniqueKeysWithValues: jwtSecretsString.map{ (JWKIdentifier(string: $0.key), $0.value) })
		
		self.hostname = try container.decodeIfPresent(String.self, forKey: .hostname)
		self.port = try container.decodeIfPresent(Int.self, forKey: .port)
	}
	
	enum CodingKeys : String, CodingKey {
		case mainJWTKey = "main_jwt_key"
		case jwtSecrets = "jwt_secrets"
		
		case hostname
		case port
	}
	
}
