/*
 * nil2throw.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/12/28.
 */

import Foundation



public func throwIfError(_ e: Error?) throws {
	if let e = e {throw e}
}
