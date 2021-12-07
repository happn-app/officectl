/*
 * DictionaryGetValueForDynKeyLeafTag.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/9.
 */

import Foundation

import Leaf



struct DictionaryGetValueForDynKeyLeafTag : LeafTag {
	
	static let name = "dictionaryGetValueForDynKey"
	
	func render(_ ctx: LeafContext) throws -> LeafData {
		guard ctx.parameters.count == 2, let dic = ctx.parameters[0].dictionary, let key = ctx.parameters[1].string else {
			throw "usage: dictionaryGetValueForDynKey(dictionary, key)"
		}
		return dic[key] ?? .trueNil
	}
	
}
