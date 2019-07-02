/*
 * Property.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public enum RemoteProperty<T> {
	
	case fetched(T)
	case unfetched
	case unsupported
	
	func erased() -> RemoteProperty<Any?> {
		switch self {
		case .unfetched:      return .unfetched
		case .unsupported:    return .unsupported
		case .fetched(let v): return .fetched(v)
		}
	}
	
}
