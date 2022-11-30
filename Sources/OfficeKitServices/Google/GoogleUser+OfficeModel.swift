/*
 * GoogleUser+OfficeModel.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/23.
 */

import Foundation

import CommonOfficePropertiesFromHappn
import Email
import OfficeKit2



extension GoogleUser : User {
	
	public typealias IDType = Email
	public typealias PersistentIDType = String
	
	public var oU_id: Email {primaryEmail}
	public var oU_persistentID: String? {id}
	
	public var oU_isSuspended: Bool? {isSuspended}
	
	public var oU_firstName: String? {name?.givenName}
	public var oU_lastName: String? {name?.familyName}
	public var oU_nickname: String? {nil}
	
	public var oU_emails: [Email]? {[primaryEmail] + (aliases ?? []) + (nonEditableAliases ?? [])}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Any? {
		switch UserProperty(rawValue: property) {
			default: return nil
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [GoogleUser.CodingKeys]] {
		[
			.id: [.primaryEmail],
			.persistentID: [.id],
			.firstName: [.name],
			.lastName: [.name],
			.nickname: [],
			.emails: [.primaryEmail],
			.password: [.password, .passwordHashFunction]
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<GoogleUser.CodingKeys>? {
		guard let properties else {return nil}
		let keys = properties
			.compactMap{ propertyToKeys[$0] }
			.flatMap{ $0 }
		return Set(keys)
	}
	
	internal static func validFieldsParameter(from keys: Set<CodingKeys>) -> String {
		/* Retrieving the password is not possible, of course.
		 * The login, id and type are mandatory for the happn service to work properly (type not really, but whatever). */
		return (keys.subtracting([.password]) + [.primaryEmail, .id, .kind]).map{ $0.stringValue }.joined(separator: ",")
	}
	
}
