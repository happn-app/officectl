/*
 * HintsUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email
import GenericJSON

import OfficeModelCore



public typealias UserHintValue = AnyUserPropertyValue?
public typealias UserHints = [UserProperty: UserHintValue]


public struct HintsUser {
	
	public private(set) var properties = UserHints()
	
	public init(properties: UserHints = [:]) {
		self.properties = properties
	}
	
}


extension HintsUser : User {
	
	public struct NoID : Hashable, Sendable {}
	
	public var oU_id: NoID {.init()}
	public var oU_persistentID: NoID? {nil}
	
	/* Not a part of UserProtocol, but might come in handy. */
	public var hintedID: (any Sendable)? {
		properties[.id]?.flatMap{ $0 }
	}
	
	/* Not a part of UserProtocol, but might come in handy. */
	public var hintedPersistentID: (any Sendable)? {
		properties[.persistentID]?.flatMap{ $0 }
	}
	
	public var oU_isSuspended: Bool? {
		Converters.convertObjectToBool(properties[.isSuspended]?.flatMap{ $0 })
	}
	
	public var oU_firstName: String? {
		Converters.convertObjectToString(properties[.firstName]?.flatMap{ $0 })
	}
	public var oU_lastName: String? {
		Converters.convertObjectToString(properties[.lastName]?.flatMap{ $0 })
	}
	public var oU_nickname: String? {
		Converters.convertObjectToString(properties[.nickname]?.flatMap{ $0 })
	}
	
	public var oU_emails: [Email]? {
		Converters.convertObjectToEmails(properties[.emails]?.flatMap{ $0 })
	}
	
	public init(oU_id userID: NoID) {
		self.properties = [:]
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> (any Sendable)? {
		return properties[.init(stringLiteral: property)]?.flatMap{ $0 }
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		func checkEquality<T1 : Equatable, T2 : Equatable>(_ v1: T1, _ v2: T2) -> Bool {
			switch (v1, v2) {
				case let v2 as T1: return v1 == v2
				default:           return false
			}
		}
		
		let changed: Bool
		if let newValue {
			if let oldValueEquatable = properties[property] as? any Equatable, let newValueEquatable = newValue as? any Equatable {
				changed = checkEquality(oldValueEquatable, newValueEquatable)
			} else {
				changed = false
			}
			properties[property] = newValue
		} else {
			changed = (properties[property] != nil)
			properties.removeValue(forKey: property)
		}
		return changed ? .successChanged : .successUnchanged
	}
	
}
