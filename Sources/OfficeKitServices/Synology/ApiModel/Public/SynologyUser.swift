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
	
	public var passwordNeverExpires: Bool?
	public var cannotChangePassword: Bool?
	/* I could’ve made a property wrapper but I got lazy for this one… */
	public var passwordLastChangeSynoTimestamp: Int?
	public var passwordLastChange: Date? {
		get {passwordLastChangeSynoTimestamp.flatMap{ Date(timeIntervalSince1970: TimeInterval($0 * 24 * 60 * 60)) }}
		set {passwordLastChangeSynoTimestamp = newValue.flatMap{ Int($0.timeIntervalSince1970 / (24 * 60 * 60)) }}
	}
	
	public var expired: Expiration?
	
	internal func forPatching(properties: Set<CodingKeys>) -> SynologyUser {
		var ret = SynologyUser(name: name)
		ret.uid = uid
		for property in properties {
			switch property {
				case .uid, .name: (/*nop*/)
				case .email:                           ret.email                           = email
				case .description:                     ret.description                     = description
				case .expired:                         ret.expired                         = expired
				case .passwordNeverExpires:            ret.passwordNeverExpires            = passwordNeverExpires
				case .cannotChangePassword:            ret.cannotChangePassword            = cannotChangePassword
				case .passwordLastChangeSynoTimestamp: ret.passwordLastChangeSynoTimestamp = passwordLastChangeSynoTimestamp
			}
		}
		return ret
	}
	
	public enum CodingKeys : String, CodingKey {
		case name, uid
		case email, description
		case passwordNeverExpires = "passwd_never_expire",
			  cannotChangePassword = "cannot_chg_passwd",
			  passwordLastChangeSynoTimestamp = "password_last_change"
		case expired
	}
	
}
