/*
 * UserId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



public enum UserId : Hashable {
	
	case distinguishedName(LDAPDistinguishedName)
	case googleUserId(String)
	case gitHubId(String)
	case email(Email)
	
	public var distinguishedName: LDAPDistinguishedName? {
		switch self {
		case .distinguishedName(let dn): return dn
		default:                         return nil
		}
	}
	
	public var googleUserId: String? {
		switch self {
		case .googleUserId(let id): return id
		default:                    return nil
		}
	}
	
	public var gitHubId: String? {
		switch self {
		case .gitHubId(let id): return id
		default:                return nil
		}
	}
	
	public var email: Email? {
		switch self {
		case .email(let email): return email
		default:                return nil
		}
	}
	
	public var stringValue: String {
		switch self {
		case .distinguishedName(let dn): return "ldap:" + dn.stringValue
		case .googleUserId(let id):      return "ggl:" + id
		case .gitHubId(let id):          return "github:" + id
		case .email(let mail):           return "email:" + mail.stringValue
		}
	}
	
}
