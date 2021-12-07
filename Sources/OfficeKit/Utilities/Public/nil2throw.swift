/*
 * nil2throw.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/12/2018.
 */

import Foundation



public func nil2throw<T>(_ v: T?, _ fieldName: String = "Unknown") throws -> T {
	guard let v = v else {throw MissingFieldError(fieldName)}
	return v
}

public func throwIfError(_ e: Error?) throws {
	if let e = e {throw e}
}
