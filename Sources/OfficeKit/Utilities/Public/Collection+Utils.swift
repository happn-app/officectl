/*
 * Collection+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/11/03.
 */

import Foundation



public extension Collection {
	
	var onlyElement: Element? {
		guard let e = first, count == 1 else {
			return nil
		}
		return e
	}
	
}
