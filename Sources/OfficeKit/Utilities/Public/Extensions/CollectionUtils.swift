/*
 * CollectionUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/08/2019.
 */

import Foundation



extension Collection {
	
	public var onlyElement: Element? {
		guard let e = first, count == 1 else {
			return nil
		}
		return e
	}
	
}


extension Sequence {
	
	public func group<IdentifierType : Hashable>(by keyForValue: (Element) -> IdentifierType) throws -> [IdentifierType: Element] {
		let grouped = Dictionary(grouping: self, by: keyForValue)
		return try grouped.mapValues{ groupedElement in
			guard let element = groupedElement.onlyElement else {
				throw InternalError(message: "Invalid sequence which contains at least two elements with the same id.")
			}
			return element
		}
	}
	
}
