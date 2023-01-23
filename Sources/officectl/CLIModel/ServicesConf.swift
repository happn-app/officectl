/*
 * ServicesConf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/17.
 */

import Foundation

import OfficeModelCore



struct ServicesConf : Decodable, Sendable {
	
	var authServiceID: Tag
	
	enum CodingKeys : String, CodingKey {
		case authServiceID = "auth_service_id"
	}
	
}
