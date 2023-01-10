/*
 * PropertyChangeResult.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2023/01/10.
 */

import Foundation



public enum PropertyChangeResult {
	
	case successChanged
	case successUnchanged
	
	case failure(Failure)
	
	public static func anyFailure(_ err: Error) -> Self {
		if let known = err as? Failure {return .failure(known)}
		else                           {return .failure(.other(err))}
	}
	
	public enum Failure : Error {
		
		case unsupportedProperty
		case readOnlyProperty
		
		case invalidValueType
		case valueConversionFailed
		
		/** When an unremovable property is set to `nil`. */
		case unremovableProperty
		
		case other(Error)
		
	}
	
	public var isSuccessful: Bool {
		switch self {
			case .successChanged, .successUnchanged: return true
			case .failure:                           return false
		}
	}
	
	public var propertyWasModified: Bool {
		switch self {
			case .successChanged:             return true
			case .successUnchanged, .failure: return false
		}
	}
	
}
