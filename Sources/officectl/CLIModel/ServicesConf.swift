/*
 * ServicesConf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/17.
 */

import Foundation



struct ServicesConf : Decodable, Sendable {
	
	var authServiceID: String
	
	enum CodingKeys : String, CodingKey {
		case authServiceID = "auth_service_id"
	}
	
}
