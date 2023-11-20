/*
 * LDAPObject+OfficeModel.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import Email

import OfficeKit



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
	
	public var oU_nonStandardProperties: Set<String> {
		return Set(record.keys.map{ Self.customAttributePrefix + ":" + $0.rawValue })
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		guard let (oid, _) = Self.customUserPropertyToAttribute(UserProperty(rawValue: property)) else {
			Conf.logger?.warning("Invalid property name.")
			return nil
		}
		return record[oid]
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		do {
			switch property {
				case .id:
					/* When communicating with LDAP, libldap uses the DN to specify which object the operation is destined to.
					 * AFAICT there is no way to _change_ the DN of an entry using LDAP, one has to delete the entry and create it again. */
					Conf.logger?.warning("Changing the ID of an LDAP user is not recommended at all as it will probably not do what you expect. Please delete and re-create the object instead.")
					return Self.setProperty(&id, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToDN)
					
				case .persistentID, .isSuspended:
					return .failure(.unsupportedProperty)
					
				case .firstName:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
					let c1 = LDAPInetOrgPersonClass.GivenName .setValueIfNeeded([newValue],         in: &record)
					let c2 = LDAPPersonClass       .CommonName.setValueIfNeeded([computedFullName], in: &record)
					return (c1 || c2 ? .successChanged : .successUnchanged)
					
				case .lastName:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
					let c1 = LDAPPersonClass.Surname   .setValueIfNeeded([newValue],         in: &record)
					let c2 = LDAPPersonClass.CommonName.setValueIfNeeded([computedFullName], in: &record)
					return (c1 || c2 ? .successChanged : .successUnchanged)
					
				case .nickname:
					return .failure(.unsupportedProperty)
					
				case .emails:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
					return (LDAPInetOrgPersonClass.Mail.setValueIfNeeded(newValue, in: &record) ? .successChanged : .successUnchanged)
					
				default:
					let newValue = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToDatas)
					guard let (oid, className) = Self.customUserPropertyToAttribute(property) else {
						throw PropertyChangeResult.Failure.unsupportedProperty
					}
					return (record.setValueIfNeeded(newValue, for: oid, expectedObjectClassName: className) ? .successChanged : .successUnchanged)
			}
			
		} catch {
			return .anyFailure(error)
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
	
	private static func customUserPropertyToAttribute(_ property: UserProperty) -> (oid: LDAPObjectID, className: String?)? {
		/* Expected format:
		 *  "happn/ldap:custom-attribute:"/*prefix for custom property*/ + "className:propertyName"
		 * The className can be empty if unknown, in which case nil is returned for className. */
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
		return (oid, !className.isEmpty ? className : nil)
	}
	
}
