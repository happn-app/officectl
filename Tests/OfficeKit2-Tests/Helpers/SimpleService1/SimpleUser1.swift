/*
 * SimpleUser1.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/11/04.
 */

import Foundation

import Email

import OfficeKit2



struct SimpleUser1<UserIDType : Hashable & Sendable> : User {
	
	typealias PersistentUserIDType = Never
	
	init(oU_id userID: UserIDType) {
		self.oU_id = userID
	}
	
	init(oU_id userID: UserIDType, oU_firstName firstName: String?, oU_lastName lastName: String?) {
		self.oU_id = userID
		self.oU_firstName = firstName
		self.oU_lastName = lastName
	}
	
	var oU_id: UserIDType
	var oU_persistentID: Never?
	
	var oU_isSuspended: Bool?
	
	var oU_firstName: String?
	var oU_lastName: String?
	var oU_nickname: String?
	
	var oU_emails: [Email]?
	
	func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nil
	}
	
	mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		switch property {
			case .id:          return Self.setProperty(&oU_id, to: newValue, allowTypeConversion: convert, converter: { $0 as? UserIDType })
			case .isSuspended: return Self.setOptionalProperty(&oU_isSuspended, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToBool)
			case .firstName:   return Self.setOptionalProperty(&oU_firstName,   to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .lastName:    return Self.setOptionalProperty(&oU_lastName,    to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .nickname:    return Self.setOptionalProperty(&oU_nickname,    to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .emails:      return Self.setOptionalProperty(&oU_emails,      to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
				
			default: return .failure(.unsupportedProperty)
		}
	}
	
}
