/*
 * Converters.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/09.
 */

import Foundation

import Email
import GenericJSON
import UnwrapOrThrow



public enum Converters {
}

public extension Converters {
	
	enum StringNumericParsingBase {
		
		case ten
		case sixteen
		
	}
	
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
	
	/**
	 Try and convert the given object to a `Bool`ean.
	 
	 Supported input object types:
	 - `Bool`
	 
	 - Anything that parses as an `Int` (input must be a whole number) with the `RESTNumericTransformer`.
	 If value is `0`, converts to `false`, if `1`, converts to `true`, for any other value, conversion fails (return `nil`).
	 
	 - `String`: The string will be tested against common boolean string values (in English, indeed).
	 For `true`, we test for `"true"`, `"t"`, `"yes"`, `"y"` and `"ok"`;
	 for `false`, we test for `"false"`, `"f"`, `"no"`, `"n"` and `"ko"`.
	 
	 - Note: Does **not** convert any number to a boolean like `NSNumber` does.
	 
	 From <https://github.com/happn-app/BMO/blob/0.2.1/Sources/RESTUtils/Utilities/RESTBoolTransformer.swift>. */
	static func convertObjectToBool(_ obj: Any?, trimmedChars: CharacterSet) -> Bool? {
		let obj = unwrapJSONIfNeeded(obj)
		
		if let b = obj as? Bool {return b}
		
		/* Note: For our use case, trimmedChars and ignoredCharacters can be the same, even though their meaning is not the same.
		 * (Because the values that mean something to us are on one character only.) */
		switch convertObjectToInt(obj, ignoredCharacters: trimmedChars, parserMustScanWholeString: true, scannerLocale: nil, failOnNonWholeNumbers: true, parseStringAsDouble: false) {
			case 0?: return false
			case 1?: return true
			case .some: return nil
			default: (/*nop*/)
		}
		
		guard let str = (obj as? String)?.trimmingCharacters(in: trimmedChars).lowercased() else {return nil}
		
		/* Checking for standard bool strings. */
		if Set(arrayLiteral: "true", "t", "yes", "y", "ok").contains(str) {return true}
		if Set(arrayLiteral: "false", "f", "no", "n", "ko").contains(str) {return false}
		
		return nil
	}
	
	static func convertObjectToBool(_ obj: Any?) -> Bool? {
		return convertObjectToBool(obj, trimmedChars: .whitespacesAndNewlines)
	}
	
	/**
	 Try and convert the given object to an `Int`.
	 
	 Supported input object types:
	 - `Int`
	 
	 - `NSNumber` (or any type that dynamically casts into an `NSNumber` in Swift like `Double`, `Float`, `Decimal`, etc.):
	 will return the double value of the number,
	 rounded using the given rounding method,
	 then cast to an `Int` using an exact conversion (fails but does not crash if the value is too big or too small).
	 The default rounding method is the “schoolbook rounding.”
	 If the `failOnNonWholeNumbers` is set to `true`, the double value is checked to be whole before being converted into an `Int`.
	 This is relative to precision problems (for instance a very big number with a decimal value might see its decimal value dropped when converted to a Double and thus being considered as a whole number).
	 
	 - `String`: The object will be parsed with a Scanner, with the given ignored characters (by default whitespaces and newlines) and the given locale.
	 If `parseStringAsDouble` is `true`, will try and parse the string as a `Double` and return the value, converting the same way as with an `NSNumber`.
	 
	 From <https://github.com/happn-app/BMO/blob/0.2.1/Sources/RESTUtils/Utilities/RESTNumericTransformer.swift>. */
	static func convertObjectToInt(
		_ obj: Any?, doubleToIntRoundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, stringParsingBase: StringNumericParsingBase = .ten,
		ignoredCharacters: CharacterSet = .whitespacesAndNewlines, parserMustScanWholeString: Bool = true, scannerLocale: Locale? = nil,
		failOnNonWholeNumbers: Bool = false, parseStringAsDouble: Bool = false
	) -> Int? {
		let obj = unwrapJSONIfNeeded(obj)
		
		if let n = obj as? Int {return n}
		if let n = obj as? NSNumber {
			guard !failOnNonWholeNumbers || isDecimalWhole(n.decimalValue) else {return nil}
			return Int(exactly: n.doubleValue.rounded(doubleToIntRoundingRule))
		}
		
		guard let str = obj as? String else {return nil}
		
		if !parseStringAsDouble {
			/* Let's parse the number. */
			var int = 0
			let scanner = Scanner(string: str)
			scanner.locale = scannerLocale
			scanner.charactersToBeSkipped = ignoredCharacters
			switch stringParsingBase {
				case .ten: guard scanner.scanInt(&int) else {return nil}
				case .sixteen:
					var uint64 = UInt64(0)
					guard scanner.scanHexInt64(&uint64), let i = Int(exactly: uint64) else {return nil}
					int = i
			}
			guard !parserMustScanWholeString || scanner.isAtEnd else {return nil}
			return int
		} else {
			var double: Double = 0
			let scanner = Scanner(string: str)
			scanner.locale = scannerLocale
			scanner.charactersToBeSkipped = ignoredCharacters
			switch stringParsingBase {
				case .ten:     guard let d = scanner.scanDouble()   else {return nil}; double = d
				case .sixteen: guard scanner.scanHexDouble(&double) else {return nil}
			}
			guard !parserMustScanWholeString || scanner.isAtEnd else {return nil}
			guard !failOnNonWholeNumbers || isDecimalWhole(Decimal(double)) else {return nil}
			return Int(exactly: double.rounded(doubleToIntRoundingRule))
		}
	}
	
	/**
	 Try and convert the given object to a `Float`.
	 
	 Supported input object types:
	 - `Float`
	 
	 - `NSNumber` (or any type that dynamically casts into an NSNumber in Swift like `Int`, `Double`, `Decimal`, etc.).
	 
	 - `String`: The object will be parsed with a Scanner, with the given ignored characters (by default whitespaces and newlines) and the given locale.
	 
	 From <https://github.com/happn-app/BMO/blob/0.2.1/Sources/RESTUtils/Utilities/RESTNumericTransformer.swift>. */
	static func convertObjectToFloat(
		_ obj: Any?, stringParsingBase: StringNumericParsingBase = .ten,
		ignoredCharacters: CharacterSet = .whitespacesAndNewlines, parserMustScanWholeString: Bool = true,
		scannerLocale: Locale? = nil
	) -> Float? {
		let obj = unwrapJSONIfNeeded(obj)
		
		if let f = obj as? Float {return f}
		if let n = obj as? NSNumber {return n.floatValue}
		
		guard let str = obj as? String else {return nil}
		
		/* Let's parse the number. */
		var float: Float = 0
		let scanner = Scanner(string: str)
		scanner.locale = scannerLocale
		scanner.charactersToBeSkipped = ignoredCharacters
		switch stringParsingBase {
			case .ten:     guard let f = scanner.scanFloat()  else {return nil}; float = f
			case .sixteen: guard scanner.scanHexFloat(&float) else {return nil}
		}
		guard !parserMustScanWholeString || scanner.isAtEnd else {return nil}
		return float
	}
	
	/**
	 Try and convert the given object to a `Double`.
	 
	 Supported input object types:
	 - `Double`
	 
	 - `NSNumber` (or any type that dynamically casts into an `NSNumber` in Swift like `Int`, `Float`, `Decimal`, etc.).
	 
	 - `String`: The object will be parsed with a Scanner, with the given ignored characters (by default whitespaces and newlines) and the given locale.
	 
	 From <https://github.com/happn-app/BMO/blob/0.2.1/Sources/RESTUtils/Utilities/RESTNumericTransformer.swift>. */
	static func convertObjectToDouble(
		_ obj: Any?, stringParsingBase: StringNumericParsingBase = .ten,
		ignoredCharacters: CharacterSet = .whitespacesAndNewlines, parserMustScanWholeString: Bool = true,
		scannerLocale: Locale? = nil
	) -> Double? {
		let obj = unwrapJSONIfNeeded(obj)
		
		if let d = obj as? Double {return d}
		if let n = obj as? NSNumber {return n.doubleValue}
		
		guard let str = obj as? String else {return nil}
		
		/* Let’s parse the number. */
		var double: Double = 0
		let scanner = Scanner(string: str)
		scanner.locale = scannerLocale
		scanner.charactersToBeSkipped = ignoredCharacters
		switch stringParsingBase {
			case .ten:     guard let d = scanner.scanDouble()   else {return nil}; double = d
			case .sixteen: guard scanner.scanHexDouble(&double) else {return nil}
		}
		guard !parserMustScanWholeString || scanner.isAtEnd else {return nil}
		return double
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


private extension Converters {
	
	/* From https://stackoverflow.com/a/46331176/1152894
	 * I found many variations on the same method to check whether a decimal is whole, this method seemed the best. */
	static func isDecimalWhole(_ d: Decimal) -> Bool {
		guard !d.isZero else {return true}
		guard d.isNormal else {return false}
		
		var d = d
		var rounded = Decimal()
		NSDecimalRound(&rounded, &d, 0, .plain)
		return d == rounded
	}
	
}
