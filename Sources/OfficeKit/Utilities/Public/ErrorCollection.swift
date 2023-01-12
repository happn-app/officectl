/*
 * ErrorCollection.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/26.
 */

import Foundation



/** Multiple errors are reported (e.g. when something is tried on multiple sources and fails on all of them). */
public struct ErrorCollection : Error {
	
	public let errors: [Error]
	
	public init(_ e: [Error]) {
		errors = e
	}
	
}
