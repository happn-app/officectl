/*
 * Yaml+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 21/03/2019.
 */

import Foundation

import OfficeKit
import Yaml



extension Yaml {
	
	func stringOrThrow() throws -> String {
		return try nil2throw(string, "Expected String in Yaml")
	}
	
	func arrayOrThrow() throws -> [Yaml] {
		return try nil2throw(array, "Expected Array in Yaml")
	}
	
	func arrayOfStringOrThrow() throws -> [String] {
		return try arrayOrThrow().map{ try $0.stringOrThrow() }
	}
	
}
