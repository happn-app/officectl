/*
 * UserIDBuilder.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/11/03.
 */

import Foundation

import Email
import XibLoc



public struct UserIDBuilder {
	
	public var format: String
	
	public init(format: String) {
		self.format = format
	}
	
	public func inferID(fromUser user: any User, additionalVariables: [String: String] = [:]) throws -> String {
		var transformError: Error?
		let resolvingInfo = Str2StrXibLocInfo()
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "|"), replacement: { variable in
				guard let v = (user.valueForProperty(.init(stringLiteral: variable)) as? String) ?? additionalVariables[variable] else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "MISSING_VALUE"
				}
				return v
			})!
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "*"), replacement: { text in
				guard let transformed = text.lowercased().applyingTransform(.stripDiacritics, reverse: false) else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "TRANSFORM_FAILED"
				}
				return transformed.replacingOccurrences(of: " ", with: "-")
			})!
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "#"), replacement: { text in
				guard let email = Email(rawValue: text) else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "INVALID_EMAIL"
				}
				return email.localPart
			})!
		
		let ret = format.applying(xibLocInfo: resolvingInfo)
		try transformError?.throwSelf()
		return ret
	}
	
}
