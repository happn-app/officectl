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
	
	/* We’re currently using XibLoc for simpler dev, but we should have a structured format. */
	public var format: String
	
	public init(format: String) {
		self.format = format
	}
	
	public func inferID(fromUser user: any User, additionalVariables: [String: Any] = [:]) throws -> String {
		var transformError: Error?
		let resolvingInfo = Str2StrXibLocInfo()
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "|"), replacement: { variable in
				guard let v = (user.valueForProperty(.init(stringLiteral: variable)) ?? additionalVariables[variable]) as? String else {
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
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "#"), replacement: { variable in
				guard let email = (user.valueForProperty(.init(stringLiteral: variable)) ?? additionalVariables[variable]) as? Email else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "MISSING_VALUE_OR_INVALID_EMAIL"
				}
				return email.localPart
			})!
			.addingSimpleReturnTypeReplacement(tokens: OneWordTokens(token: "?"), replacement: { text in
				let parts = text.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
				guard parts.count == 2 else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "INVALID_DN_SPLIT_FORMAT"
				}
				
				let variable = String(parts[0])
				guard let dn = (user.valueForProperty(.init(stringLiteral: variable)) ?? additionalVariables[variable]) as? DistinguishedName else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "MISSING_VALUE_OR_INVALID_DISTINGUISHED_NAME"
				}
				
				let dnValue = String(parts[1])
				guard let extractedValue = dn.relativeDistinguishedNameValues(for: dnValue).onlyElement else {
					transformError = Err.cannotCreateLogicalUserFromWrappedUser
					return "MORE_THAN_ONE_VALUE_FOR_DN_EXTRACTION"
				}
				
				return extractedValue
			})!
		
		let ret = format.applying(xibLocInfo: resolvingInfo)
		try transformError?.throwSelf()
		return ret
	}
	
}
