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
	
	mutating func oU_setValue<V>(_ newValue: V?, forProperty property: OfficeKit2.UserProperty, allowIDChange: Bool, convertMismatchingTypes convertValue: Bool) -> Bool where V : Sendable {
		switch property {
			case .id:
				guard let newValue = newValue as? UserIDType else {
					return false
				}
				return Self.setValueIfNeeded(newValue, in: &oU_id)
				
			case .isSuspended: return Self.setValueIfNeeded(newValue, in: &oU_isSuspended, converter: (!convertValue ? { $0 as? Bool }    : Converters.convertObjectToBool(_:)))
			case .firstName:   return Self.setValueIfNeeded(newValue, in: &oU_firstName,   converter: (!convertValue ? { $0 as? String }  : Converters.convertObjectToString(_:)))
			case .lastName:    return Self.setValueIfNeeded(newValue, in: &oU_lastName,    converter: (!convertValue ? { $0 as? String }  : Converters.convertObjectToString(_:)))
			case .nickname:    return Self.setValueIfNeeded(newValue, in: &oU_nickname,    converter: (!convertValue ? { $0 as? String }  : Converters.convertObjectToString(_:)))
			case .emails:      return Self.setValueIfNeeded(newValue, in: &oU_emails,      converter: (!convertValue ? { $0 as? [Email] } : Converters.convertObjectToEmails(_:)))
				
			default: return false
		}
	}
	
}
