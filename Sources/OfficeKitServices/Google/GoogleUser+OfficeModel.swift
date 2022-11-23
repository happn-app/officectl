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
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<GoogleUser.CodingKeys> {
		let properties = properties ?? Set(UserProperty.standardProperties)
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
/*
extension GoogleUser : DirectoryUser {
	
	public typealias IDType = Email
	public typealias PersistentIDType = String
	
	public var userID: Email {
		return primaryEmail
	}
	
	public var remotePersistentID: RemoteProperty<String> {
		return _id
	}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return .set(primaryEmail)
	}
	
	public var remoteOtherEmails: RemoteProperty<[Email]> {
		return _aliases.map{ $0 ?? [] }
	}
	
	public var remoteFirstName: RemoteProperty<String?> {
		return _name.map{ $0.givenName }
	}
	
	public var remoteLastName: RemoteProperty<String?> {
		return _name.map{ $0.familyName }
	}
	
	public var remoteNickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
*/
