/*
 * GoogleUser+OfficeModel.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/23.
 */

import Foundation

import CommonOfficePropertiesFromHappn
import Crypto
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
	
	/**
	 Does _not_ contain the non-editable aliases.
	 Rationale: we want this property to be editable. */
	public var oU_emails: [Email]? {[primaryEmail] + (aliases ?? [])}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch UserProperty(rawValue: property) {
			/* We do not support any non-standard properties for now. */
			default: return nil
		}
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes convertValue: Bool) -> Bool {
		let primaryEmailProperty = UserProperty("primaryEmail")
		switch property {
			case .id, primaryEmailProperty:
				guard allowIDChange else {return false}
				guard let newValue else {
					Conf.logger?.error("Asked to remove the id of a user (nil value for id in hints). This is illegal, I’m not doing it.")
					return false
				}
				return Self.setValueIfNeeded(newValue, in: &primaryEmail, converter: (!convertValue ? { $0 as? Email } : Converters.convertObjectToEmail(_:)))
				
			case .isSuspended:
				return Self.setValueIfNeeded(newValue, in: &isSuspended, converter: (!convertValue ? { $0 as? Bool } : Converters.convertObjectToBool(_:)))
				
			case .firstName:
				var newName = name ?? Name()
				if Self.setValueIfNeeded(newValue, in: &newName.givenName, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:))) {
					name = newName
					return true
				}
				return false
				
			case .lastName:
				var newName = name ?? Name()
				if Self.setValueIfNeeded(newValue, in: &newName.familyName, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:))) {
					name = newName
					return true
				}
				return false
				
			case .nickname:
				var newName = name ?? Name()
				if Self.setValueIfNeeded(newValue, in: &newName.displayName, converter: (!convertValue ? { $0 as? String } : Converters.convertObjectToString(_:))) {
					name = newName
					return true
				}
				return false
				
				
			case .emails:
				guard let newValue else {
					Conf.logger?.error("Cannot remove all the emails of a gougle user (id is an email…).")
					return false
				}
				guard let emails = (!convertValue ? newValue as? [Email] : Converters.convertObjectToEmails(newValue)) else {
					return false
				}
				guard let first = emails.first else {
					Conf.logger?.error("Cannot remove all the emails of a gougle user (id is an email…).")
					return false
				}
				guard allowIDChange || first == primaryEmail else {
					return false
				}
				primaryEmail = first
				aliases = Array(emails.dropFirst())
				return true
				
			case .password:
				if let newValue {
					guard let newPass = (!convertValue ? newValue as? String : Converters.convertObjectToString(newValue)) else {
						return false
					}
					let hash = Insecure.SHA1.hash(data: Data(newPass.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
					let touched = (password != hash || passwordHashFunction != .sha1 || changePasswordAtNextLogin != false)
					changePasswordAtNextLogin = false
					passwordHashFunction = .sha1
					password = hash
					return touched
					
				} else {
					let touched = (password != nil || passwordHashFunction != nil || changePasswordAtNextLogin != nil)
					password = nil
					passwordHashFunction = nil
					changePasswordAtNextLogin = nil
					return touched
				}
				
			default:
				return false
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
			.emails: [.primaryEmail, .aliases],
			.firstName: [.name],
			.lastName: [.name],
			.nickname: [],
			.password: [.password, .passwordHashFunction, .changePasswordAtNextLogin],
			/* Other. */
			UserProperty("primaryEmail"): [.primaryEmail]
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
