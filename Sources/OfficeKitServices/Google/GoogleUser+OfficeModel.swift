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
	
	public init(oU_id userID: Email) {
		self.primaryEmail = userID
	}
	
	public var oU_id: Email {primaryEmail}
	public var oU_persistentID: String? {id}
	
	public var oU_isSuspended: Bool? {isSuspended}
	
	public var oU_firstName: String? {name?.givenName}
	public var oU_lastName: String? {name?.familyName}
	public var oU_nickname: String? {nil}
	
	public var oU_emails: [Email]? {[primaryEmail] + (aliases ?? []) + (nonEditableAliases ?? [])}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
#warning("TODO")
		switch UserProperty(rawValue: property) {
			default: return nil
		}
	}
	
	public func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool {
		let primaryEmailProperty = UserProperty("primaryEmail")
		switch property {
			case .id, primaryEmailProperty:
				guard allowIDChange else {return false}
				guard let newValue else {
					Conf.logger?.error("Asked to remove the id of a user (nil value for id in hints). This is illegal, I’m not doing it.")
					return false
				}
#warning("TODO (we’ll have to change setValue to return the set of the modified properties, maybe.")
				return false
//				touchedKey = GoogleUser.setValueIfNeeded(newValue, in: &primaryEmail)
//				if touchedKey {
//					/* We add both.
//					 * `property` will be added twice, but that’s not a problem. */
//					ret.insert(.id)
//					ret.insert(primaryEmailProperty)
//				}
				
#warning("TODO")
//			case .firstName: return GoogleUser.setValueIfNeeded(GoogleUser.Name(givenName: newValue,             familyName: user.name?.familyName), in: &user.name)
//			case .lastName:  return GoogleUser.setValueIfNeeded(GoogleUser.Name(givenName: user.name?.givenName, familyName: newValue),              in: &user.name)
//			case .password:
//				if let newValue {
//					let hashed = Insecure.SHA1.hash(data: Data(newValue.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
//					touchedKey = (user.password != hashed || user.passwordHashFunction != .sha1)
//					user.password = hashed
//					user.passwordHashFunction = .sha1
//					user.changePasswordAtNextLogin = false
//				} else {
//					touchedKey = (user.password != nil || user.passwordHashFunction != nil)
//					user.password = nil
//					user.passwordHashFunction = nil
//					user.changePasswordAtNextLogin = nil
//				}
//				/* TODO: Other properties. */
			default: return false
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [GoogleUser.CodingKeys]] {
		[
			/* Standard. */
			.id: [.primaryEmail],
			.persistentID: [.id],
			.isSuspended: [.isSuspended],
			.emails: [.primaryEmail],
			.firstName: [.name],
			.lastName: [.name],
			.nickname: [],
			.password: [.password, .passwordHashFunction]
			/* Other. */
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<GoogleUser.CodingKeys> {
		let properties = properties ?? Set(UserProperty.standardProperties + [])
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
