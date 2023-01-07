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
	
	static let customAttributePrefix = "happn/ldap:custom-attribute:"
	
	public typealias UserIDType = LDAPDistinguishedName
	public typealias PersistentUserIDType = Never
	
	public init(oU_id userID: LDAPDistinguishedName) {
		self.id = userID
		self.record = [LDAPTopClass.ObjectClass.descrOID: [Data(LDAPInetOrgPersonClass.name.utf8)]]
	}
	
	public init?(oU_id userID: LDAPDistinguishedName, record: LDAPRecord) {
		self.id = userID
		self.record = record
		guard isInetOrgPerson else {
			return nil
		}
	}
	
	public var isInetOrgPerson: Bool {
		return allObjectClasses?.contains(LDAPInetOrgPersonClass.name) ?? false
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
		guard property.hasPrefix(Self.customAttributePrefix) else {
			return nil
		}
		let attributeName = String(property.dropFirst(Self.customAttributePrefix.count))
		guard !attributeName.isEmpty, let oid = LDAPObjectID(rawValue: attributeName) else {
			Conf.logger?.warning("Invalid property name.")
			return false
		}
		return record[oid]
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes convertValue: Bool) -> Bool {
		switch property {
			case .id:
				guard allowIDChange else {return false}
				guard let newValue else {
					Conf.logger?.error("Asked to remove the id of a user. This is illegal, I’m not doing it.")
					return false
				}
				/* When communicating with LDAP, libldap uses the DN to specify which object the operation is destined to.
				 * AFAICT there is no way to _change_ the DN of an entry using LDAP, one has to delete the entry and create it again. */
				Conf.logger?.warning("Changing the ID of an LDAP is not recommended at all as it will probably not do what you expect. Please delete and re-create the object instead.")
				return Self.setRequiredValueIfNeeded(newValue, in: &id, converter: (!convertValue ? { $0 as? LDAPDistinguishedName } : Converters.convertObjectToDN(_:)))
				
			case .persistentID:
				return false
				
			case .isSuspended:
				return false
				
			case .firstName:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				let c1 = LDAPInetOrgPersonClass.GivenName .setValueIfNeeded([newValue],         in: &record)
				let c2 = LDAPPersonClass       .CommonName.setValueIfNeeded([computedFullName], in: &record)
				return c1 || c2
				
			case .lastName:
				guard let newValue = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {return false}
				let c1 = LDAPPersonClass.Surname   .setValueIfNeeded([newValue],         in: &record)
				let c2 = LDAPPersonClass.CommonName.setValueIfNeeded([computedFullName], in: &record)
				return c1 || c2
				
			case .nickname:
				return false
				
			case .emails:
				guard let newValue = (!convertValue ? newValue as? [Email] : Converters.convertObjectToEmails(newValue)) else {return false}
				return LDAPInetOrgPersonClass.Mail.setValueIfNeeded(newValue, in: &record)
				
			default:
				guard let newValue = (!convertValue ? newValue as? [Data] : Converters.convertObjectToDatas(newValue)) else {return false}
				guard let (oid, className) = Self.customUserPropertyToAttribute(property) else {
					return false
				}
				return record.setValueIfNeeded(newValue, for: oid, expectedObjectClassName: className)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToOIDs: [UserProperty: [LDAPObjectID.Descr]] {
		return [
			/* Standard. */
			.id: [],
			.persistentID: [],
			.isSuspended: [],
			.emails: [LDAPInetOrgPersonClass.Mail.descr],
			.firstName: [LDAPInetOrgPersonClass.GivenName.descr, LDAPPersonClass.CommonName.descr], /* Full name is not needed for reading but for writing. */
			.lastName:  [LDAPPersonClass       .Surname  .descr, LDAPPersonClass.CommonName.descr], /* Full name is not needed for reading but for writing. */
			.nickname: [],
			/* Other. */
		]
	}
	
	internal static func oidsFromProperties(_ properties: Set<UserProperty>) -> Set<LDAPObjectID> {
		let keys = properties
			.union([.id, .persistentID]) /* id is definitely mandatory; persistent ID we could let go. */
			.compactMap{ propertyToOIDs[$0] }
			.flatMap{ $0 }
			.map{ LDAPObjectID.descr($0) }
		return Set(keys).union([LDAPTopClass.ObjectClass.descrOID] + properties.compactMap{ customUserPropertyToAttribute($0)?.oid })
	}
	
	internal static func attributeNamesFromProperties(_ properties: Set<UserProperty>?) -> Set<String>? {
		guard let properties else {
			return nil
		}
		
		return Set(oidsFromProperties(properties).map{ $0.rawValue })
	}
	
	private static func customUserPropertyToAttribute(_ property: UserProperty) -> (oid: LDAPObjectID, className: String)? {
		/* Expected format:
		 *  "happn/ldap:custom-attribute:"/*prefix for custom property*/ + "className:propertyName" */
		let propertyName = property.rawValue
		guard propertyName.hasPrefix(Self.customAttributePrefix) else {
			return nil
		}
		let attributeAndClassName = String(propertyName.dropFirst(Self.customAttributePrefix.count))
		guard !attributeAndClassName.isEmpty else {
			Conf.logger?.warning("Invalid property name.")
			return nil
		}
		let split = attributeAndClassName.split(separator: ":", omittingEmptySubsequences: false)
		guard split.count == 2, let oid = LDAPObjectID(rawValue: String(split[1])) else {
			Conf.logger?.warning("Invalid property name.")
			return nil
		}
		let className = String(split[0])
		return (oid, className)
	}
	
}
