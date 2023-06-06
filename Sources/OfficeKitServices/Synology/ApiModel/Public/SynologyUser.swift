/*
 * SynologyUser.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import Email

import OfficeKit



public struct SynologyUser : Sendable, Hashable, Codable {
	
	public enum Expiration : String, Codable, Sendable {
		
		case now
		case normal
		
	}
	
	public var name: String
	public var uid: Int?
	
	@EmptyIsNil
	public var email: Email?
	public var description: String?
	
	public var expired: Expiration?
	
	internal func forPatching(properties: Set<CodingKeys>) -> SynologyUser {
		var ret = SynologyUser(name: name)
		ret.uid = uid
		for property in properties {
			switch property {
				case .uid, .name: (/*nop*/)
				case .email:       ret.email       = email
				case .description: ret.description = description
				case .expired:     ret.expired     = expired
			}
		}
		return ret
	}
	
	public enum CodingKeys : String, CodingKey {
		case name, uid
		case email, description
		case expired
	}
	
}
