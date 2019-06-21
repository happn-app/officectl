/*
 * FallibleStringInitable.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/06/2019.
 */

import Foundation



public protocol FallibleStringInitable {
	
	init(string: String) throws
	
}
