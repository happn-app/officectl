/*
 * SnailCaseToHumanLeafTag.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/9.
 */

import Foundation

import Leaf
import Vapor



struct SnailCaseToHumanLeafTag : LeafTag {
	
	static let name = "snailCaseToHuman"
	
	func render(_ ctx: LeafContext) throws -> LeafData {
		guard let string = ctx.parameters.onlyElement?.string else {
			throw "parameter given to snailCaseToHuman leaf tag is not a single string"
		}
		return .string(string.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
	}
	
}
