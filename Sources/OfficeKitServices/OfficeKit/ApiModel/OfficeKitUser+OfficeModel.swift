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
		self.nonStandardProperties = [:]
		self.opaqueUserInfo = nil
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
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		switch property {
			case .id:
				return Self.setProperty(&id, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .persistentID:
				return Self.setProperty(&persistentID, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .isSuspended:
				return Self.setOptionalProperty(&isSuspended, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToBool)
				
			case .firstName:
				return Self.setOptionalProperty(&firstName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .lastName:
				return Self.setOptionalProperty(&lastName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .nickname:
				return Self.setOptionalProperty(&nickname, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .emails:
				return Self.setOptionalProperty(&emails, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
				
			default:
				assert(!property.isStandard)
				if let newValue {
					return Self.setProperty(&nonStandardProperties[property.rawValue], to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToJSON)
					
				} else {
					let changed = (nonStandardProperties[property.rawValue] != nil)
					nonStandardProperties.removeValue(forKey: property.rawValue)
					return (changed ? .successChanged : .successUnchanged)
				}
		}
	}
	
}