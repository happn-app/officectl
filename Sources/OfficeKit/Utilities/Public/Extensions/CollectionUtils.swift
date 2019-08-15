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
