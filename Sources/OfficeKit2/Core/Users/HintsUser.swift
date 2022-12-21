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
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool {
		if let newValue {
			properties[property] = newValue
			/* We always return true as we cannot check for equality with previous value as it is not Equatable. */
			return true
		} else {
			let hadValue = (properties[property] != nil)
			properties.removeValue(forKey: property)
			return hadValue
		}
	}
	
}
