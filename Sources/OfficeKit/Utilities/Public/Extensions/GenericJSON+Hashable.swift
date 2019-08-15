/*
 * GenericJSON+Hashable.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/07/2019.
 */

import Foundation

import GenericJSON



extension JSON : Hashable {
	
	public func hash(into hasher: inout Hasher) {
		switch self {
		case .null:          hasher.combine(0 as UInt8)
		case .bool(let v):   hasher.combine(1 as UInt8); hasher.combine(v)
		case .number(let v): hasher.combine(2 as UInt8); hasher.combine(v)
		case .string(let v): hasher.combine(3 as UInt8); hasher.combine(v)
		case .array(let v):  hasher.combine(4 as UInt8); hasher.combine(v)
		case .object(let v): hasher.combine(5 as UInt8); hasher.combine(v)
		}
	}
	
}
