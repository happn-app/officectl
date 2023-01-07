/*
 * LDAPObject+OfficeModel.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import Email

import OfficeKit2



extension LDAPObject : User {
	
	public typealias UserIDType = LDAPDistinguishedName
	public typealias PersistentUserIDType = Never
	
	public init(oU_id userID: LDAPDistinguishedName) {
		self.id = userID
		self.record = [LDAPTopClass.ObjectClass.attributeDescription.descrOID: [Data(LDAPInetOrgPersonClass.name.utf8)]]
	}
	
	public init?(oU_id userID: LDAPDistinguishedName, record: LDAPRecord) {
		self.id = userID
		self.record = record
		guard isInetOrgPerson else {
			return nil
		}
	}
	
	public var isInetOrgPerson: Bool {
		return (try? LDAPTopClass.ObjectClass.value(in: record))?.contains(LDAPInetOrgPersonClass.name) ?? false
	}
	
	public var oU_id: LDAPDistinguishedName {
		return id
	}
	
	public var oU_persistentID: Never? {
		return nil
	}
	
	public var oU_isSuspended: Bool? {
		return nil
	}
	
	/* LDAPInetOrgPerson <https://www.ietf.org/rfc/rfc2798.txt> */
	public var oU_firstName: String? {
		return try? LDAPInetOrgPersonClass.GivenName.value(in: record)?.first
	}
	
	public var oU_lastName: String? {
		return try? LDAPPersonClass.Surname.value(in: record)?.first
	}
	
	public var oU_nickname: String? {
		return nil
	}
	
	public var oU_emails: [Email]? {
		return try? LDAPInetOrgPersonClass.Mail.value(in: record)
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nil
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes convertValue: Bool) -> Bool {
		switch property {
			case .id:
				guard allowIDChange else {return false}
				guard let newValue else {
					Conf.logger?.error("Asked to remove the id of a user. This is illegal, I’m not doing it.")
					return false
				}
				return Self.setRequiredValueIfNeeded(newValue, in: &id, converter: (!convertValue ? { $0 as? LDAPDistinguishedName } : Converters.convertObjectToDN(_:)))
				
			case .persistentID:
				return false
				
			case .isSuspended:
				return false
				
			case .firstName:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				record[LDAPInetOrgPersonClass.GivenName .attributeDescription.descrOID] = [Data(newValue.utf8)]
				record[LDAPPersonClass       .CommonName.attributeDescription.descrOID] = [Data(computedFullName.utf8)]
				return true
			case .lastName:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				record[LDAPPersonClass.Surname   .attributeDescription.descrOID] = [Data(newValue.utf8)]
				record[LDAPPersonClass.CommonName.attributeDescription.descrOID] = [Data(computedFullName.utf8)]
				return true
				
			case .nickname:
				return false
				
			case .emails:
				guard let newValue = (!convertValue ? newValue as? [Email] : Converters.convertObjectToEmails(newValue)) else {return false}
				record[LDAPInetOrgPersonClass.Mail.attributeDescription.descrOID] = newValue.map{ Data($0.rawValue.utf8) }
				return true
				
			default:
				return false
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToAttributeDescriptions: [UserProperty: [AttributeDescription]] {
		[
			/* Standard. */
			.id: [],
			.persistentID: [],
			.isSuspended: [],
			.emails: [LDAPInetOrgPersonClass.Mail.attributeDescription],
			.firstName: [LDAPInetOrgPersonClass.GivenName.attributeDescription, LDAPPersonClass.CommonName.attributeDescription], /* Full name is not needed for reading but for writing. */
			.lastName:  [LDAPPersonClass       .Surname  .attributeDescription, LDAPPersonClass.CommonName.attributeDescription], /* Full name is not needed for reading but for writing. */
			.nickname: [],
			/* Other. */
		]
	}
	
	internal static func attributeDescriptionsFromProperties(_ properties: Set<UserProperty>) -> Set<AttributeDescription> {
		let keys = properties
			.union([.id, .persistentID]) /* id is definitely mandatory; persistent ID we could let go. */
			.compactMap{ propertyToAttributeDescriptions[$0] }
			.flatMap{ $0 }
		return Set(keys).union([LDAPTopClass.ObjectClass.attributeDescription])
	}
	
	internal static func attributeDescriptionsFromProperties(_ properties: Set<UserProperty>?) -> Set<AttributeDescription>? {
		guard let properties else {
			return nil
		}
		
		return attributeDescriptionsFromProperties(properties)
	}
	
	internal static func attributeNamesFromProperties(_ properties: Set<UserProperty>?) -> Set<String>? {
		return (attributeDescriptionsFromProperties(properties)?.map(\.descr.rawValue)).flatMap{ Set($0) }
	}
	
}
