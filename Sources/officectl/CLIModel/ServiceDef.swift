/*
 * ServiceDef.swift
 * 
 *
 * Created by François Lamboley on 2023/01/17.
 * 
 */

import Foundation

@preconcurrency import GenericJSON



struct ServiceDef : Decodable, Sendable {
	
	var providerID: String
	var config: JSON
	
	enum CodingKeys : String, CodingKey {
		case providerID = "provider_id"
		case config
	}
	
}
