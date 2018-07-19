/*
 * LDAPObject.swift
 * officectl
 *
 * Created by François Lamboley on 04/07/2018.
 */

import Foundation



public struct LDAPObject {
	
	public let distinguishedName: String
	public let parsedDistinguishedName: [(key: String, value: String)]?
	public var attributes: [String: [Data]]
	
	public var hasValidDistinguishedName: Bool {
		return parsedDistinguishedName != nil
	}
	
	public init(distinguishedName dn: String, attributes attrs: [String: [Data]]) {
		parsedDistinguishedName = try? LDAPObject.parseDistinguishedName(dn)
		distinguishedName = dn
		attributes = attrs
	}
	
	public func relativeDistinguishedNameValues(for key: String) -> [String]? {
		return parsedDistinguishedName?.compactMap{ (currentKey, currentValue) in
			guard currentKey == key else {return nil}
			return currentValue
		}
	}
	
	public func stringValues(for key: String) -> [String]? {
		guard let v = attributes[key] else {return nil}
		return v.compactMap{ String(data: $0, encoding: .utf8) }
	}
	
	/* Return the first value for the given key which has a valid UTF-8 string
	 * representation. */
	public func firstStringValue(for key: String) -> String? {
		return stringValues(for: key)?.first /* This is not very optimized… */
	}
	
	public func singleValue(for key: String) -> Data? {
		guard let a = attributes[key], let f = a.first, a.count == 1 else {return nil}
		return f
	}
	
	public func singleStringValue(for key: String) -> String? {
		return singleValue(for: key).flatMap{ String(data: $0, encoding: .utf8) }
	}
	
	public var inetOrgPerson: LDAPInetOrgPerson? {
		guard stringValues(for: "objectClass")?.contains("inetOrgPerson") ?? false else {return nil}
		guard let sn = stringValues(for: "sn"), let cn = stringValues(for: "cn") else {return nil}
		
		let ret = LDAPInetOrgPerson(dn: distinguishedName, sn: sn, cn: cn)
		ret.uid = singleStringValue(for: "uid")
		ret.givenName = stringValues(for: "givenName")
		ret.userPassword = singleStringValue(for: "userPassword")
		ret.mail = stringValues(for: "mail")?.compactMap{ Email(string: $0) }
		return ret
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private static func parseDistinguishedName(_ dn: String) throws -> [(key: String, value: String)] {
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
						throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got EOF, expected more key characters"])
					}
					
				case .waitEndKeyBackslash:
					switch c {
					case .some(let c) where CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(c.unicodeScalars.first!):
						assert(backslashValue.isEmpty)
						backslashValue = String(c)
						return .waitEndKeyBackslash2
						
					case .some(let c):
						currentKey.append(c)
						return .waitEndKey
						
					case nil:
						throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got EOF, expected more key characters after a backslash"])
					}
					
				case .waitEndKeyBackslash2:
					switch c {
					case .some(let c) where CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(c.unicodeScalars.first!):
						assert(backslashValue.count == 1)
						backslashValue.append(c)
						defer {backslashValue = ""}
						
						let intValue = Int(backslashValue, radix: 16)!
						guard let scalar = Unicode.Scalar(intValue) else {
							throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert backslash value \(backslashValue) to unicode scalar"])
						}
						
						currentKey.append(Character(scalar))
						return .waitEndKey
						
					default:
						throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got invalid char or EOF for a numeric LDAP escape"])
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
					case .some(let c) where CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(c.unicodeScalars.first!):
						assert(backslashValue.isEmpty)
						backslashValue = String(c)
						return .waitEndValueBackslash2
						
					case .some(let c):
						currentValue.append(c)
						return .waitEndValue
						
					case nil:
						throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got EOF, expected more value characters after a backslash"])
					}
					
				case .waitEndValueBackslash2:
					switch c {
					case .some(let c) where CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(c.unicodeScalars.first!):
						assert(backslashValue.count == 1)
						backslashValue.append(c)
						defer {backslashValue = ""}
						
						let intValue = Int(backslashValue, radix: 16)!
						guard let scalar = Unicode.Scalar(intValue) else {
							throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert backslash value \(backslashValue) to unicode scalar"])
						}
						
						currentValue.append(Character(scalar))
						return .waitEndValue
						
					default:
						throw NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Got invalid char or EOF for a numeric LDAP escape"])
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
		
		return res
	}
	
}
