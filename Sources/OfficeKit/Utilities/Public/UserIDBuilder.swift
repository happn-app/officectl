/*
 * UserIDBuilder.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/11/03.
 */

import Foundation

import Email
import XibLoc



public struct UserIDBuilder : Sendable, Codable {
	
	public enum InferenceError : Error {
		case syntaxError(message: String)
		case valueNotFound
		case invalidValueType
		case invalidVariableParameters
		case dnExtractFailed
	}
	
	/* We’re currently using XibLoc for simpler dev, but we should have a structured format. */
	public var format: String
	
	public init(format: String) {
		self.format = format
	}
	
	public func inferID(fromUser user: (any User)?, additionalVariables: [String: Any] = [:]) -> String? {
		/*
		 $var[,string[,transform]]$ -> Exact type expected. If the type is not defined, it’s string.
		 |var[,string[,transform]]| -> Conversion allowed.
		 *No more çedil or spaces* -> no-more-cedil-or-spaces (nor uppercase)
		 */
		var gotError = false
		let resolvingInfo = Str2StrXibLocInfo()
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "$"), replacement: { transformInfo in
				guard let r = try? Self.valueForVariableTransform(transformInfo, allowTypeConversion: false, user: user, additionalVariables: additionalVariables) else {
					gotError = true
					return "ERROR"
				}
				return r
			})!
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "|"), replacement: { transformInfo in
				guard let r = try? Self.valueForVariableTransform(transformInfo, allowTypeConversion: true, user: user, additionalVariables: additionalVariables) else {
					gotError = true
					return "ERROR"
				}
				return r
			})!
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "*"), replacement: { text in
				guard let transformed = text.lowercased().applyingTransform(.stripDiacritics, reverse: false) else {
					gotError = true
					return "TRANSFORM_FAILED"
				}
				return transformed.replacingOccurrences(of: " ", with: "-")
			})!
		
		let ret = format.applying(xibLocInfo: resolvingInfo)
		guard !gotError else {return nil}
		return ret
	}
	
	private static func valueForVariableTransform(_ transformInfo: String, allowTypeConversion: Bool, user: (any User)?, additionalVariables: [String: Any]) throws -> String {
		/* First let’s parse the transform info.
		 * Format is: variableName,expectedVariableType,transform1,transform2 where transforms are optional.
		 * Escape char is the backslash (\). */
		var escaping = false
		var transformComponents = [""]
		for c in transformInfo {
			guard !escaping else {
				escaping = false
				continue
			}
			switch c {
				case "\\": escaping = true
				case ",": transformComponents.append("")
				default:  transformComponents[transformComponents.endIndex - 1].append(String(c))
			}
		}
		transformComponents.reverse()
		guard let variableName = transformComponents.popLast(), !variableName.isEmpty else {
			throw InferenceError.syntaxError(message: "Empty variable name")
		}
		let variableTypeStr = transformComponents.popLast() ?? "string"
		guard let variableType = VariableType(rawValue: variableTypeStr) else {
			throw InferenceError.syntaxError(message: "No or invalid variable type")
		}
		let reversedTransformParams = transformComponents
		
		/* Next let’s retrieve the value for the variable name. */
		guard let value = user?.oU_valueForProperty(.init(stringLiteral: variableName)) ?? additionalVariables[variableName] else {
			throw InferenceError.valueNotFound
		}
		
		switch variableType {
			case .dn:     return try processDNValue    (value, allowTypeConversion: allowTypeConversion, reversedParameters: reversedTransformParams)
			case .email:  return try processEmailValue (value, allowTypeConversion: allowTypeConversion, reversedParameters: reversedTransformParams)
			case .string: return try processStringValue(value, allowTypeConversion: allowTypeConversion, reversedParameters: reversedTransformParams)
		}
	}
	
	private static func processDNValue(_ value: Any, allowTypeConversion: Bool, reversedParameters: [String]) throws -> String {
		guard let dn = (allowTypeConversion ? Converters.convertObjectToDN(value) : value as? LDAPDistinguishedName) else {
			throw InferenceError.invalidValueType
		}
		let extractPrefix = "extract:"
		var reversedParameters = reversedParameters
		while let parameter = reversedParameters.popLast() {
			switch parameter {
				case let str where str.hasPrefix(extractPrefix):
					let extractedProperty = String(str.dropFirst(extractPrefix.count))
					guard let extractedValue = dn.relativeDistinguishedNameValues(for: extractedProperty).onlyElement else {
						throw InferenceError.dnExtractFailed
					}
					return try processStringValue(extractedValue, allowTypeConversion: false, reversedParameters: reversedParameters)
					
				default:
					throw InferenceError.invalidVariableParameters
			}
		}
		return dn.stringValue
	}
	
	private static func processEmailValue(_ value: Any, allowTypeConversion: Bool, reversedParameters: [String]) throws -> String {
		guard let email = (allowTypeConversion ? Converters.convertObjectToEmail(value) : (value as? MightBeEmail)?.email) else {
			throw InferenceError.invalidValueType
		}
		var reversedParameters = reversedParameters
		while let parameter = reversedParameters.popLast() {
			switch parameter {
				case "local_part":
					return try processStringValue(email.localPart, allowTypeConversion: false, reversedParameters: reversedParameters)
					
				case "domain_part":
					return try processStringValue(email.domainPart, allowTypeConversion: false, reversedParameters: reversedParameters)
					
				default:
					throw InferenceError.invalidVariableParameters
			}
		}
		return email.rawValue
	}
	
	private static func processStringValue(_ value: Any, allowTypeConversion: Bool, reversedParameters: [String]) throws -> String {
		guard let string = (allowTypeConversion ? Converters.convertObjectToString(value) : value as? String) else {
			throw InferenceError.invalidValueType
		}
		/* We do not support any parameters for now. */
		guard reversedParameters.isEmpty else {
			throw InferenceError.invalidVariableParameters
		}
		return string
	}
	
	private enum VariableType : String {
		case string
		case email
		case dn
	}
	
}
