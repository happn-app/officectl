/*
 * SynologyUser+OfficeModel.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import Email
import OfficeKit



extension SynologyUser : User {
	
	public typealias UserIDType = String
	public typealias PersistentUserIDType = Int
	
	public init(oU_id userID: String) {
		self.name = userID
	}
	
	public var oU_id: String {name}
	public var oU_persistentID: Int? {uid}
	
	public var oU_isSuspended: Bool? {
		switch expiration {
			case nil:              return nil
			case .now?:            return true
			case .none?:           return false
			case .date(let date)?: return date < Date()
		}
	}
	
	public var oU_firstName: String? {nil}
	public var oU_lastName: String? {nil}
	public var oU_nickname: String? {nil}
	
	public var oU_emails: [Email]? {
		return email.flatMap{ [$0] }
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
//		let passwordProperty = UserProperty(rawValue: SynologyService.providerID + "/password")
		let uidProperty = UserProperty(SynologyService.providerID + "/uid")
		switch property {
			case .id, uidProperty:
				return Self.setProperty(&uid, to: newValue, allowTypeConversion: convert, converter: { Converters.convertObjectToInt($0) })
				
			case .isSuspended:
				return .failure(.unsupportedProperty)
				
			case .firstName: return .failure(.unsupportedProperty)
			case .lastName:  return .failure(.unsupportedProperty)
			case .nickname:  return .failure(.unsupportedProperty)
				
			case .emails:
				return .failure(.unsupportedProperty)
//				do {
//					guard let newValue else {
//						Conf.logger?.error("Cannot remove all the emails of an Synology user (id is an email…).")
//						throw PropertyChangeResult.Failure.unremovableProperty
//					}
//					
//					let emails = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
//					guard emails.count <= 2 else {
//						Conf.logger?.error("An Synology user can have at most 2 emails.")
//						throw PropertyChangeResult.Failure.valueConversionFailed
//					}
//					guard let first = emails.first else {
//						Conf.logger?.error("Cannot remove all the emails of an Synology user (id is an email…).")
//						throw PropertyChangeResult.Failure.unremovableProperty
//					}
//					let other = emails.dropFirst().first
//					let changed = (userPrincipalName != first || mail != other)
//					userPrincipalName = first
//					mail = other
//					return changed ? .successChanged : .successUnchanged
//					
//				} catch {
//					return .anyFailure(error)
//				}
				
//			case passwordProperty:
//				do {
//					if let newValue {
//						let newPass = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
//						let newPassProfile = PasswordProfile(
//							forceChangePasswordNextSignIn: false,
//							forceChangePasswordNextSignInWithMfa: false,
//							password: newPass
//						)
//						let changed = (newPassProfile != passwordProfile)
//						passwordProfile = newPassProfile
//						return changed ? .successChanged : .successUnchanged
//						
//					} else {
//						let changed = (passwordProfile != nil)
//						passwordProfile = nil
//						return changed ? .successChanged : .successUnchanged
//					}
//					
//				} catch {
//					return .anyFailure(error)
//				}
				
			default:
				return .failure(.unsupportedProperty)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [SynologyUser.CodingKeys]] {
		[
			/* Standard. */
			.id: [.name],
			.persistentID: [.uid],
			.isSuspended: [.expiration],
			.emails: [.email],
			.firstName: [],
			.lastName: [],
			.nickname: []/*,
			.init(rawValue: SynologyService.providerID + "/password"): [.passwordProfile]*/
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<SynologyUser.CodingKeys> {
		let properties = (properties ?? Set(UserProperty.standardProperties)).union([.id])
		let keys = properties
			.compactMap{ propertyToKeys[$0] }
			.flatMap{ $0 }
		return Set(keys)
	}
	
}
