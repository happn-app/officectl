/*
 * Dictionary+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/20.
 */

import Foundation



public extension Dictionary {
	
	func mapKeys<T : Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
		return try Dictionary<T, Value>(uniqueKeysWithValues: map{ try (transform($0.key), $0.value) })
	}
	
}
