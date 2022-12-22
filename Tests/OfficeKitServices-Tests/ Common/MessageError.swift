/*
 * MessageError.swift
 * CommonForOfficeKitServicesTests
 *
 * Created by François Lamboley on 2022/12/22.
 */

import Foundation



public struct MessageError : Error {
	
	public var message: String
	
	public init(message: String) {
		self.message = message
	}
	
}
