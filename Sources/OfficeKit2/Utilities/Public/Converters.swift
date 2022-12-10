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
	
	public static func unwrapJSONIfNeeded(_ obj: Any?) -> Any? {
		return (obj as? JSON).flatMap(unwrapJSON(_:)) ?? obj
	}
	
	public static func unwrapJSON(_ json: JSON) -> Any? {
		switch json {
			case     .null:      return nil
			case let .bool(b):   return b
			case let .number(n): return n
			case let .string(s): return s
			case let .array(a):  return a.map(unwrapJSON(_:))
			case let .object(o): return o.mapValues(unwrapJSON(_:))
		}
	}
	
	public static func convertObjectToBool(_ obj: Any?) -> Bool? {
		return RESTBoolTransformer.convertObjectToBool(unwrapJSONIfNeeded(obj))
	}
	
	public static func convertObjectToInt(_ obj: Any?) -> Int? {
		RESTNumericTransformer.convertObjectToInt(unwrapJSONIfNeeded(obj))
	}
	
	public static func convertObjectToFloat(_ obj: Any?) -> Float? {
		RESTNumericTransformer.convertObjectToFloat(unwrapJSONIfNeeded(obj))
	}
	
	public static func convertObjectToDouble(_ obj: Any?) -> Double? {
		RESTNumericTransformer.convertObjectToDouble(unwrapJSONIfNeeded(obj))
	}
	
	public static func convertObjectToString(_ obj: Any?) -> String? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		/* Hint: A String or a BinaryInteger is LosslessStringConvertible. */
		return (obj as? LosslessStringConvertible).flatMap{ String($0) }
	}
	
	public static func convertObjectToEmail(_ obj: Any?) -> Email? {
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
	
	public static func convertObjectToEmails(_ obj: Any?) -> [Email]? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		switch obj {
			case let arr   as [Email]: return arr
			case let email as  Email:  return [email]
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
	
}
