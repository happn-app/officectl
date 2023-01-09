/*
 * WrappedOptional.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation



extension WrappedOptional : Sendable where Wrapped : Sendable {}
public struct WrappedOptional<Wrapped : Codable> : Codable {
	
	public var value: Wrapped?
	
	public init(_ value: Wrapped?) {
		self.value = value
	}
	
}
