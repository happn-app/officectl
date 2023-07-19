/*
 * CollectionUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/13.
 */

import Foundation



extension Sequence {
	
	public func group<IdentifierType : Hashable>(by keyForValue: (Element) -> IdentifierType) throws -> [IdentifierType: Element] {
		return try group(by: keyForValue, mappingValues: { $0 })
	}
	
	public func group<IdentifierType : Hashable, NewValueType>(by keyForValue: (Element) -> IdentifierType, mappingValues valueMapper: (Element) -> NewValueType) throws -> [IdentifierType: NewValueType] {
		let grouped = Dictionary(grouping: self, by: keyForValue)
		return try grouped.mapValues{ groupedElement in
			guard let element = groupedElement.onlyElement else {
				throw InternalError(message: "Invalid sequence which contains at least two elements with the same ID.")
			}
			return valueMapper(element)
		}
	}
	
}


extension Dictionary {
	
	internal func mapKeys<T : Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
		return try Dictionary<T, Value>(uniqueKeysWithValues: map{ try (transform($0.key), $0.value) })
	}
	
}
