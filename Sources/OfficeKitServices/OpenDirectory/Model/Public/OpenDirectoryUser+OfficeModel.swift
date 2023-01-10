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
	
	public typealias UserIDType = String
	public typealias PersistentUserIDType = UUID
	
	public init(oU_id userID: String) {
		self.init(id: userID)
	}
	
	public var oU_id: String {
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
		/* kODAttributeTypeEMailContacts also exists; should we return both?
		 * I don’t think it’s necessary: in the users browser in Server, the value seems to be from this attribute. */
		return try? properties[kODAttributeTypeEMailAddress]?.asMultiString?.map{ try Email(rawValue: $0) ?! NotAnEmail() }
	}
	
	public var distinguishedName: LDAPDistinguishedName? {
		return properties[kODAttributeTypeMetaRecordName]?.asString.flatMap{ try? LDAPDistinguishedName(string: $0) }
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nil
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		do {
			switch property {
				case .id:
					return Self.setProperty(&id, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
					
				case .persistentID:
					Conf.logger?.error("The persistent ID cannot be changed.")
					return .failure(.readOnlyProperty)
					
				case .isSuspended:
					return .failure(.unsupportedProperty)
					
				case .firstName:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
					let c1 = Self.setProperty(&properties[kODAttributeTypeFirstName], to: .string(newValue))
					let c2 = Self.setProperty(&properties[kODAttributeTypeFullName],  to: .string(computedFullName))
					return (c1 || c2 ? .successChanged : .successUnchanged)
					
				case .lastName:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
					let c1 = Self.setProperty(&properties[kODAttributeTypeLastName], to: .string(newValue))
					let c2 = Self.setProperty(&properties[kODAttributeTypeFullName], to: .string(computedFullName))
					return (c1 || c2 ? .successChanged : .successUnchanged)
					
				case .nickname:
					return Self.setProperty(&properties[kODAttributeTypeNickName], to: newValue, allowTypeConversion: convert, converter: { Converters.convertObjectToString($0).flatMap{ .string($0) } })
					
				case .emails:
					return Self.setProperty(&properties[kODAttributeTypeEMailAddress], to: newValue, allowTypeConversion: convert, converter: { Converters.convertObjectToEmails($0).flatMap{ .multiString($0.map(\.rawValue)) } })
					
				default:
					throw PropertyChangeResult.Failure.unsupportedProperty
			}
			
		} catch {
			return .anyFailure(error)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToAttributeNames: [UserProperty: [String]] {
		[
			/* Standard. */
			.id: [kODAttributeTypeRecordName],
			.persistentID: [kODAttributeTypeGUID],
			.isSuspended: [],
			.emails: [kODAttributeTypeEMailAddress/*, kODAttributeTypeEMailContacts*/],
			.firstName: [kODAttributeTypeFirstName, kODAttributeTypeFullName], /* Full name is not needed for reading but for writing. */
			.lastName: [kODAttributeTypeLastName, kODAttributeTypeFullName], /* Full name is not needed for reading but for writing. */
			.nickname: [kODAttributeTypeNickName],
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
