/*
 * Converters.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/09.
 */

import Foundation

import Email
import GenericJSON
import RESTUtils
import UnwrapOrThrow



public enum Converters {
}

public extension Converters {
	
	static func unwrapJSONIfNeeded(_ obj: Any?) -> Any? {
		return (obj as? JSON).flatMap(unwrapJSON(_:)) ?? obj
	}
	
	static func unwrapJSON(_ json: JSON) -> Any? {
		switch json {
			case     .null:      return nil
			case let .bool(b):   return b
			case let .number(n): return n
			case let .string(s): return s
			case let .array(a):  return a.map(unwrapJSON(_:))
			case let .object(o): return o.mapValues(unwrapJSON(_:))
		}
	}
	
	static func convertObjectToBool(_ obj: Any?) -> Bool? {
		return RESTBoolTransformer.convertObjectToBool(unwrapJSONIfNeeded(obj))
	}
	
	static func convertObjectToInt(_ obj: Any?) -> Int? {
		RESTNumericTransformer.convertObjectToInt(unwrapJSONIfNeeded(obj))
	}
	
	static func convertObjectToFloat(_ obj: Any?) -> Float? {
		RESTNumericTransformer.convertObjectToFloat(unwrapJSONIfNeeded(obj))
	}
	
	static func convertObjectToDouble(_ obj: Any?) -> Double? {
		RESTNumericTransformer.convertObjectToDouble(unwrapJSONIfNeeded(obj))
	}
	
	static func convertObjectToString(_ obj: Any?) -> String? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		/* Hint: A String or a BinaryInteger is LosslessStringConvertible. */
		switch obj {
			case let strish as LosslessStringConvertible: return String(strish)
			case let data  as  Data:  return                      String(data: data, encoding: .utf8) /* We happily and shamelessly assume UTF-8 */
			case let datas as [Data]: return datas.first.flatMap{ String(data: $0,   encoding: .utf8) } /* Case for LDAP */
			default: return nil
		}
	}
	
	static func convertObjectToEmail(_ obj: Any?) -> Email? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		switch obj {
			case let email as Email: return email
			default:
				guard let str = convertObjectToString(obj) else {
					return nil
				}
				return Email(rawValue: str)
		}
	}
	
	static func convertObjectToEmails(_ obj: Any?) -> [Email]? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		struct InvalidEmailFound : Error {}
		switch obj {
			case let arr   as [Email]: return arr
			case let email as  Email:  return [email]
			case let arr   as [Any]:   return try? arr.map{ try convertObjectToEmail($0) ?! InvalidEmailFound() }
			default:
				guard let str = convertObjectToString(obj) else {
					return nil
				}
				/* We split the emails around the newline: AFAICT a newline is always invalid in an email adresse, whatever RFC you use to parse them.
				 * Usually emails are separated by a comma, but a comma _can_ be in a valid email and we’d have to properly parse stuff to extract the different email addresses. */
				let splitStr = str.split(separator: "\n")
				struct Internal__InvalidEmailErrorMarker : Error {} /* Used as a marker if we encounter an invalid email. */
				return try? splitStr.map{ try Email(rawValue: String($0)) ?! Internal__InvalidEmailErrorMarker() }
		}
	}
	
	static func convertObjectToDN(_ obj: Any?) -> LDAPDistinguishedName? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		switch obj {
			case let dn as LDAPDistinguishedName: return dn
			default:
				guard let str = convertObjectToString(obj) else {
					return nil
				}
				return try? LDAPDistinguishedName(string: str)
		}
	}
	
	static func convertObjectToData(_ obj: Any?) -> Data? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		switch obj {
			case let data as Data: return data
			default:
				guard let str = convertObjectToString(obj) else {
					return nil
				}
				return Data(str.utf8)
		}
	}
	
	static func convertObjectToDatas(_ obj: Any?) -> [Data]? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		struct InvalidDataFound : Error {}
		switch obj {
			case let datas as [Data]: return datas
			case let arr   as [Any]:   return try? arr.map{ try convertObjectToData($0) ?! InvalidDataFound() }
			default:
				return convertObjectToData(obj).flatMap{ [$0] }
		}
	}
	
	static func convertObjectToDate(_ obj: Any?, dateFormatter: (String) -> Date?) -> Date? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		switch obj {
			case let date as Date: return date
			default:
				guard let str = convertObjectToString(obj) else {
					return nil
				}
				return dateFormatter(str)
		}
	}
	static func objectToDateConverter(with formatter: @escaping (String) -> Date?) -> (Any?) -> Date? {
		return { convertObjectToDate($0, dateFormatter: formatter) }
	}
	
	static func convertObjectToJSON(_ obj: Any?) -> JSON? {
		switch obj {
			case let json as JSON:           return json
			case let encodable as Encodable: return try? JSON(encodable: encodable)
			default:                         return nil
		}
	}
	
}

public extension Converters {
	
	static func convertPropertyValue<T, U>(_ toConvert: U, allowTypeConversion: Bool, converter: (U) -> T?) throws -> T {
		if allowTypeConversion {
			guard let converted = converter(toConvert) else {
				throw PropertyChangeResult.Failure.valueConversionFailed
			}
			return converted
		} else {
			guard let converted = toConvert as? T else {
				throw PropertyChangeResult.Failure.invalidValueType
			}
			return converted
		}
	}
	
}
