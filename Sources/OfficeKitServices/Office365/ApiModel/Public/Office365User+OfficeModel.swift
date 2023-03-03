/*
 * Office365User+OfficeModel.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/03.
 */

import Foundation

import Email
import OfficeKit



extension Office365User : User {
	
	public typealias UserIDType = Email
	public typealias PersistentUserIDType = String
	
	public init(oU_id userID: Email) {
		self.userPrincipalName = userID
	}
	
	public var oU_id: Email {userPrincipalName}
	public var oU_persistentID: String? {id}
	
	public var oU_isSuspended: Bool? {nil}
	
	public var oU_firstName: String? {givenName}
	public var oU_lastName: String? {surname}
	public var oU_nickname: String? {displayName}
	
	public var oU_emails: [Email]? {
		return [userPrincipalName] + ((mail != userPrincipalName ? mail : nil).flatMap{ [$0] } ?? [])
	}
	
	public var oU_nonStandardProperties: Set<String> {
		/* We do not support any non-standard properties for now. */
		return []
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> (Sendable)? {
		switch UserProperty(rawValue: property) {
				/* We do not support any non-standard properties for now. */
			default: return nil
		}
	}
	
	public mutating func oU_setValue<V>(_ newValue: V?, forProperty property: OfficeKit.UserProperty, convertMismatchingTypes convert: Bool) -> OfficeKit.PropertyChangeResult where V : Sendable {
		let userPrincipalNameProperty = UserProperty(Office365Service.providerID + "/userPrincipalName")
		switch property {
			case .id, userPrincipalNameProperty:
				return Self.setProperty(&userPrincipalName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmail)
				
			case .isSuspended:
				return .failure(.unsupportedProperty)
				
			case .firstName: return Self.setOptionalProperty(&givenName,   to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .lastName:  return Self.setOptionalProperty(&surname,     to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .nickname:  return Self.setOptionalProperty(&displayName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .emails:
				do {
					guard let newValue else {
						Conf.logger?.error("Cannot remove all the emails of an office365 user (id is an email…).")
						throw PropertyChangeResult.Failure.unremovableProperty
					}
					
					let emails = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
					guard emails.count <= 2 else {
						Conf.logger?.error("An office365 user can have at most 2 emails.")
						throw PropertyChangeResult.Failure.valueConversionFailed
					}
					guard let first = emails.first else {
						Conf.logger?.error("Cannot remove all the emails of an office365 user (id is an email…).")
						throw PropertyChangeResult.Failure.unremovableProperty
					}
					let other = emails.dropFirst().first
					let changed = (userPrincipalName != first && mail != other)
					userPrincipalName = first
					mail = other
					return changed ? .successChanged : .successUnchanged
					
				} catch {
					return .anyFailure(error)
				}
				
			default:
				return .failure(.unsupportedProperty)
		}
	}
	
}
