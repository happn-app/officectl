/*
 * OfficeKitUser+OfficeModel.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Email
import GenericJSON

import OfficeKit2



extension OfficeKitUser : User {
	
	public typealias UserIDType = String
	public typealias PersistentUserIDType = String
	
	public init(oU_id userID: String) {
		self.id = userID
	}
	
	public var oU_id: String {id}
	public var oU_persistentID: String? {persistentID}
	public var oU_isSuspended: Bool? {isSuspended}
	public var oU_firstName: String? {firstName}
	public var oU_lastName: String? {lastName}
	public var oU_nickname: String? {nickname}
	public var oU_emails: [Email]? {emails}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nonStandardProperties[property]
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes convertValue: Bool) -> Bool {
		switch property {
			case .id:
				guard allowIDChange else {return false}
				guard let newValue else {
					Conf.logger?.error("Asked to remove the id of a user (set to nil value). This is illegal, I’m not doing it.")
					return false
				}
				return Self.setRequiredValueIfNeeded(newValue, in: &id, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:)))
				
			case .persistentID:
				guard allowIDChange else {return false}
				return Self.setValueIfNeeded(newValue, in: &persistentID, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:)))
				
			case .isSuspended:
				return Self.setValueIfNeeded(newValue, in: &isSuspended, converter: (!convertValue ? { $0 as? Bool } : Converters.convertObjectToBool(_:)))
				
			case .firstName:
				return Self.setValueIfNeeded(newValue, in: &firstName, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:)))
				
			case .lastName:
				return Self.setValueIfNeeded(newValue, in: &lastName, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:)))
				
			case .nickname:
				return Self.setValueIfNeeded(newValue, in: &nickname, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:)))
				
			case .emails:
				return Self.setValueIfNeeded(newValue, in: &emails, converter: (!convertValue ? { $0 as? [Email] } : Converters.convertObjectToEmails(_:)))
				
			default:
				if let newValue {
					guard let newValue = (!convertValue ? newValue as? JSON : Converters.convertObjectToJSON(newValue)) else {
						return false
					}
					nonStandardProperties[property.rawValue] = newValue
					return true
				} else {
					nonStandardProperties.removeValue(forKey: property.rawValue)
					return true
				}
		}
	}
	
}
