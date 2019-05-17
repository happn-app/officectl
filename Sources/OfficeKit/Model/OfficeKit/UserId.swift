/*
 * UserId.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



public enum UserId {
	
	case distinguishedName(LDAPDistinguishedName)
	case googleUserId(String)
	case gitHubId(String)
	case email(Email)
	
	public init(string: String) throws {
		let split = string.split(separator: ":", omittingEmptySubsequences: false)
		let serviceId = split[0] /* We do not omit empty subsequences, thus we know there will be at min 1 elmt in the resulting array */
		let objectIdStr = split.dropFirst().joined(separator: ":")
		
		switch serviceId {
		case "ldap":   try self = .distinguishedName(LDAPDistinguishedName(string: objectIdStr))
		case "ggl":        self = .googleUserId(objectIdStr)
		case "github":     self = .gitHubId(objectIdStr)
		case "email":  try self = .email(nil2throw(Email(string: objectIdStr), "Invalid email"))
		default: throw InvalidArgumentError(message: "Unknown service id “\(serviceId)”")
		}
	}
	
	public var isDistinguishedName: Bool {
		switch self {
		case .distinguishedName: return true
		default:                 return false
		}
	}
	
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


extension UserId : Hashable {
}


extension UserId : CustomStringConvertible {
	
	public var description: String {
		return stringValue
	}
	
}


extension UserId : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(string: container.decode(String.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(stringValue)
	}
	
}
