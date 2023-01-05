/*
 * OpenDirectoryUser+OfficeModel.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/03.
 */

import Foundation
import OpenDirectory

import Email
import UnwrapOrThrow

import OfficeKit2



extension OpenDirectoryUser : User {
	
	public typealias UserIDType = LDAPDistinguishedName
	public typealias PersistentUserIDType = UUID
	
	public init(oU_id userID: LDAPDistinguishedName) {
		self.init(id: userID)
	}
	
	public var oU_id: LDAPDistinguishedName {
		return id
	}
	
	public var oU_persistentID: UUID? {
		return properties[kODAttributeTypeGUID]?.asString.flatMap{ UUID(uuidString: $0) }
	}
	
	public var oU_isSuspended: Bool? {
		return nil
	}
	
	public var oU_firstName: String? {
		return properties[kODAttributeTypeFirstName]?.asString
	}
	
	public var oU_lastName: String? {
		return properties[kODAttributeTypeLastName]?.asString
	}
	
	public var oU_nickname: String? {
		return properties[kODAttributeTypeNickName]?.asString
	}
	
	public var oU_emails: [Email]? {
		struct NotAnEmail : Error {}
		/* kODAttributeTypeEMailContacts also exists; should we return both? */
		return try? properties[kODAttributeTypeEMailAddress]?.asMultiString?.map{ try Email(rawValue: $0) ?! NotAnEmail() }
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nil
	}
	
	public mutating func oU_setValue<V>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes convertValue: Bool) -> Bool where V : Sendable {
		switch property {
			case .id:
				guard allowIDChange else {return false}
				guard let newValue else {
					Conf.logger?.error("Asked to remove the id of a user. This is illegal, I’m not doing it.")
					return false
				}
				return Self.setRequiredValueIfNeeded(newValue, in: &id, converter: (!convertValue ? { $0 as? LDAPDistinguishedName } : Converters.convertObjectToDN(_:)))
				
			case .persistentID:
				Conf.logger?.error("The persistent ID cannot be changed.")
				return false
				
			case .isSuspended:
				return false
				
			case .firstName:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				properties[kODAttributeTypeFirstName] = .string(newValue)
				return true
			case .lastName:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				properties[kODAttributeTypeLastName] = .string(newValue)
				return true
			case .nickname:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				properties[kODAttributeTypeNickName] = .string(newValue)
				return true
				
			case .emails:
				guard let newValue = (!convertValue ? newValue as? [Email] : Converters.convertObjectToEmails(newValue)) else {return false}
				properties[kODAttributeTypeEMailAddress] = .multiString(newValue.map(\.rawValue))
				return true
				
			case .password:
				return false
				
			default:
				return false
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToAttributeNames: [UserProperty: [String]] {
		[
			/* Standard. */
			.id: [kODAttributeTypeMetaRecordName],
			.persistentID: [kODAttributeTypeGUID],
			.isSuspended: [],
			.emails: [kODAttributeTypeEMailAddress, kODAttributeTypeEMailContacts],
			.firstName: [kODAttributeTypeFirstName],
			.lastName: [kODAttributeTypeLastName],
			.nickname: [kODAttributeTypeNickName],
			.password: [],
			/* Other. */
		]
	}
	
	internal static func attributeNamesFromProperties(_ properties: Set<UserProperty>?) -> Set<String>? {
		guard let properties else {
			return nil
		}
		
		let keys = properties
			.union([.id, .persistentID]) /* id is definitely mandatory; persistent ID we could let go. */
			.compactMap{ propertyToAttributeNames[$0] }
			.flatMap{ $0 }
		return Set(keys)
	}
	
}
