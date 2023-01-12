/*
 * Error+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/11/04.
 */

import Foundation



public extension Error {
	
	func throwSelf() throws {
		throw self
	}
	
}
