/*
 * SnailCaseToHumanLeafMethod.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/9.
 */

import Foundation

import Leaf
import Vapor



struct SnailCaseToHumanLeafMethod : LeafNonMutatingMethod, Invariant, StringReturn {
	
	static let name = "snailCaseToHuman"
	static var callSignature = [LeafCallParameter.string]
	
	func evaluate(_ params: LeafCallValues) -> LeafData {
		guard params.count == 1, let string = params[0].string else {
			return .error("parameter given to snailCaseToHuman leaf tag is not a single string")
		}
		return .string(string.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
	}
	
}
