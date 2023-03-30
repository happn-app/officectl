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
		let passwordProperty = UserProperty(rawValue: Office365Service.providerID + "/password")
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
					let changed = (userPrincipalName != first || mail != other)
					userPrincipalName = first
					mail = other
					return changed ? .successChanged : .successUnchanged
					
				} catch {
					return .anyFailure(error)
				}
				
			case passwordProperty:
				do {
					if let newValue {
						let newPass = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
						let newPassProfile = PasswordProfile(
							forceChangePasswordNextSignIn: false,
							forceChangePasswordNextSignInWithMfa: false,
							password: newPass
						)
						let changed = (newPassProfile != passwordProfile)
						passwordProfile = newPassProfile
						return changed ? .successChanged : .successUnchanged
						
					} else {
						let changed = (passwordProfile != nil)
						passwordProfile = nil
						return changed ? .successChanged : .successUnchanged
					}
					
				} catch {
					return .anyFailure(error)
				}
				
			default:
				return .failure(.unsupportedProperty)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [Office365User.CodingKeys]] {
		[
			/* Standard. */
			.id: [.userPrincipalName],
			.persistentID: [.id],
			.isSuspended: [.accountEnabled],
			.emails: [.userPrincipalName, .mail],
			.firstName: [.givenName],
			.lastName: [.surname],
			.nickname: [.displayName],
			.init(rawValue: Office365Service.providerID + "/password"): [.passwordProfile]
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<Office365User.CodingKeys> {
		let properties = (properties ?? Set(UserProperty.standardProperties)).union([.id])
		let keys = properties
			.compactMap{ propertyToKeys[$0] }
			.flatMap{ $0 }
		return Set(keys)
	}
	
	internal static func validFieldsParameter(from keys: Set<CodingKeys>) -> String {
		return (keys + [.userPrincipalName, .id]).map{ $0.stringValue }.joined(separator: ",")
	}
	
}
