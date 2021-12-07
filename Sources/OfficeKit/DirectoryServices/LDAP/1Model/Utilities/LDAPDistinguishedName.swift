/*
 * LDAPDistinguishedName.swift
 * OfficeKit
 *
 * Created by François Lamboley on 05/09/2018.
 */

import Foundation



/* RFC: https://www.ietf.org/rfc/rfc4514.txt
 * The RFC is not fully followed…
 * I know Multi-valued RDN are not supported.
 * There are probably other cases that do not correctly implement the RFC. */
public struct LDAPDistinguishedName {
	
	public static func +(_ left: LDAPDistinguishedName, _ right: LDAPDistinguishedName) -> LDAPDistinguishedName {
		return LDAPDistinguishedName(values: left.values + right.values)
	}
	
	public var values: [(key: String, value: String)]
	
	public var stringValue: String {
		return values.map{ curValue in
			/* Note: We escape the spaces anywhere in the key and value for simplicity, but we only need to escape the spaces if they’re the first or last character of the value or key. */
			/* Note: We escape the octothorpe character (“#”) anywhere in the key and value for simplicity, but we only need to escape them if they’re the first character of the value or key. */
			let replacements = [("\\", "\\\\"), (",", "\\,"), (";", "\\;"), ("<", "\\<"), (">", "\\>"), ("=", "\\="), (" ", "\\ "), ("#", "\\#"), ("\"", "\\\""), ("+", "\\+")]
			return (
				replacements.reduce(curValue.key, { $0.replacingOccurrences(of: $1.0, with: $1.1) }) +
				"=" +
				replacements.reduce(curValue.value, { $0.replacingOccurrences(of: $1.0, with: $1.1) })
			)
		}.joined(separator: ",")
	}
	
	public init(values v: [(key: String, value: String)]) {
		values = v
	}
	
	public init(uid: String, baseDN: LDAPDistinguishedName) {
		self.init(values: [(key: "uid", value: uid)] + baseDN.values)
	}
	
	public init(domain: String) {
		self.init(values: domain.split(separator: ".", omittingEmptySubsequences: false).map{ (key: "dc", value: String($0)) })
	}
	
	public init(string dn: String) throws {
		enum Engine {
			
			case waitEndKey
			case waitEndKeyBackslash
			case waitEndKeyBackslash2
			case waitEndValue
			case waitEndValueBackslash
			case waitEndValueBackslash2
			
			/* Send nil char for EOF */
			func processChar(_ c: Character?, attributes: inout [(key: String, value: String)], currentKey: inout String, currentValue: inout String, backslashValue: inout String) throws -> Engine {
				switch self {
					case .waitEndKey:
						switch c {
							case "="?:         return .waitEndValue
							case "\\"?:        return .waitEndKeyBackslash
							case .some(let c): currentKey.append(c); return .waitEndKey
							case nil:
								throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got EOF, expected more key characters"])
						}
						
					case .waitEndKeyBackslash:
						switch c {
							case .some(let c) where CharacterSet.hexadecimalCharacter.contains(c.unicodeScalars.first!):
								assert(backslashValue.isEmpty)
								backslashValue = String(c)
								return .waitEndKeyBackslash2
								
							case .some(let c):
								currentKey.append(c)
								return .waitEndKey
								
							case nil:
								throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got EOF, expected more key characters after a backslash"])
						}
						
					case .waitEndKeyBackslash2:
						switch c {
							case .some(let c) where CharacterSet.hexadecimalCharacter.contains(c.unicodeScalars.first!):
								assert(backslashValue.count == 1)
								backslashValue.append(c)
								defer {backslashValue = ""}
								
								let intValue = Int(backslashValue, radix: 16)!
								guard let scalar = Unicode.Scalar(intValue) else {
									throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert backslash value \(backslashValue) to unicode scalar"])
								}
								
								currentKey.append(Character(scalar))
								return .waitEndKey
								
							default:
								throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got invalid char or EOF for a numeric LDAP escape"])
						}
						
					case .waitEndValue:
						switch c {
							case "\\"?: return .waitEndValueBackslash
							case ","?, nil:
								attributes.append((key: currentKey, value: currentValue))
								
								currentKey = ""
								currentValue = ""
								return .waitEndKey
								
							case .some(let c):
								currentValue.append(c)
								return .waitEndValue
						}
						
					case .waitEndValueBackslash:
						switch c {
							case .some(let c) where CharacterSet.hexadecimalCharacter.contains(c.unicodeScalars.first!):
								assert(backslashValue.isEmpty)
								backslashValue = String(c)
								return .waitEndValueBackslash2
								
							case .some(let c):
								currentValue.append(c)
								return .waitEndValue
								
							case nil:
								throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got EOF, expected more value characters after a backslash"])
						}
						
					case .waitEndValueBackslash2:
						switch c {
							case .some(let c) where CharacterSet.hexadecimalCharacter.contains(c.unicodeScalars.first!):
								assert(backslashValue.count == 1)
								backslashValue.append(c)
								defer {backslashValue = ""}
								
								let intValue = Int(backslashValue, radix: 16)!
								guard let scalar = Unicode.Scalar(intValue) else {
									throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert backslash value \(backslashValue) to unicode scalar"])
								}
								
								currentValue.append(Character(scalar))
								return .waitEndValue
								
							default:
								throw NSError(domain: "com.happn.officectl.ldapDNParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got invalid char or EOF for a numeric LDAP escape"])
						}
				}
			}
			
		}
		
		var currentKey = ""
		var currentValue = ""
		var backslashValue = ""
		var res = [(key: String, value: String)]()
		
		var e = Engine.waitEndKey
		try dn.forEach{ e = try e.processChar($0, attributes: &res, currentKey: &currentKey, currentValue: &currentValue, backslashValue: &backslashValue) }
		_ = try e.processChar(nil, attributes: &res, currentKey: &currentKey, currentValue: &currentValue, backslashValue: &backslashValue)
		
		values = res
	}
	
	public func relativeDistinguishedName(for key: String) -> LDAPDistinguishedName {
		return LDAPDistinguishedName(values: values.filter{ $0.key == key })
	}
	
	public func relativeDistinguishedNameValues(for key: String) -> [String] {
		return relativeDistinguishedName(for: key).values.map{ $0.value }
	}
	
	public func relativeTrailingDistinguishedName(for key: String) -> LDAPDistinguishedName {
		var foundEnd = false
		return LDAPDistinguishedName(values: values.reversed().filter{
			guard !foundEnd else {return false}
			guard $0.key == key else {
				foundEnd = true
				return false
			}
			return true
		}.reversed())
	}
	
	public var uid: String? {
		let uids = relativeDistinguishedNameValues(for: "uid")
		guard let uid = uids.onlyElement else {return nil}
		
		return uid
	}
	
	public var dc: LDAPDistinguishedName {
		return relativeTrailingDistinguishedName(for: "dc")
	}
	
}


extension LDAPDistinguishedName : Hashable {
	
	public static func ==(lhs: LDAPDistinguishedName, rhs: LDAPDistinguishedName) -> Bool {
		/* Apparently “(key: String, value: String)” does not conform to equatable :( */
//		return lhs.values == rhs.values
		guard lhs.values.count == rhs.values.count else {return false}
		for (l, r) in zip(lhs.values, rhs.values) {
			guard l == r else {return false}
		}
		return true
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(values.map{ $0.key })
		hasher.combine(values.map{ $0.value })
	}
	
}


extension LDAPDistinguishedName : CustomStringConvertible {
	
	public var description: String {
		return stringValue
	}
	
}


extension LDAPDistinguishedName : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(string: container.decode(String.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(stringValue)
	}
	
}
