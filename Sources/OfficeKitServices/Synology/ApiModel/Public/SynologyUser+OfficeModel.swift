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
	
	/* These properties seem to be unsupported. */
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
	
	public mutating func oU_setValue<V>(_ newValue: V?, forProperty property: OfficeKit.UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult where V : Sendable {
		do {
			let passwordProperty = UserProperty(rawValue: SynologyService.providerID + "/password")
			let uidProperty = UserProperty(SynologyService.providerID + "/uid")
			switch property {
				case .id, uidProperty:
					return Self.setProperty(&uid, to: newValue, allowTypeConversion: convert, converter: { Converters.convertObjectToInt($0) })
					
				case .isSuspended:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToBool)
					return (Self.setProperty(&expiration, to: .some(newValue ? .now : .none)) ? .successChanged : .successUnchanged)
					
				case .firstName: return .failure(.unsupportedProperty)
				case .lastName:  return .failure(.unsupportedProperty)
				case .nickname:  return .failure(.unsupportedProperty)
					
				case .emails:
					let emails = try newValue.flatMap{
						try Converters.convertPropertyValue($0, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
					} ?? []
					guard emails.count <= 1 else {
						Conf.logger?.error("A Synology user can have at most 1 email.")
						throw PropertyChangeResult.Failure.valueConversionFailed
					}
					if let newEmail = emails.first {
						return (Self.setProperty(&email, to: newEmail) ? .successChanged : .successUnchanged)
					} else {
						let ret: PropertyChangeResult = (email != nil ? .successChanged : .successUnchanged)
						email = nil
						return ret
					}
					
				case passwordProperty:
					return Self.setOptionalProperty(&password, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
					
				default:
					return .failure(.unsupportedProperty)
			}
		} catch {
			return .anyFailure(error)
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
			.nickname: [],
			.init(rawValue: SynologyService.providerID + "/password"): [.password]
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
