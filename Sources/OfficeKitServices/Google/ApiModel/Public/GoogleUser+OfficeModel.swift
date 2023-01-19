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
import OfficeKit



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
	
	public var oU_nonStandardProperties: Set<String> {
		/* We do not support any non-standard properties for now except for the password one, but it’s private. */
		return []
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch UserProperty(rawValue: property) {
			/* We do not support any non-standard properties for now except for the password one, but it’s private. */
			default: return nil
		}
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		let passwordProperty = UserProperty(rawValue: "google/password")
		let primaryEmailProperty = UserProperty("primaryEmail")
		switch property {
			case .id, primaryEmailProperty:
				return Self.setProperty(&primaryEmail, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmail)
				
			case .isSuspended:
				return Self.setOptionalProperty(&isSuspended, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToBool)
				
			case .firstName:
				var newName = name ?? Name()
				let changeResult = Self.setProperty(&newName.givenName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				if changeResult.propertyWasModified {
					name = newName
				}
				return changeResult
				
			case .lastName:
				var newName = name ?? Name()
				let changeResult = Self.setProperty(&newName.familyName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				if changeResult.propertyWasModified {
					name = newName
				}
				return changeResult
				
			case .nickname:
				var newName = name ?? Name()
				let changeResult = Self.setProperty(&newName.displayName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				if changeResult.propertyWasModified {
					name = newName
				}
				return changeResult
				
			case .emails:
				do {
					guard let newValue else {
						Conf.logger?.error("Cannot remove all the emails of a gougle user (id is an email…).")
						throw PropertyChangeResult.Failure.unremovableProperty
					}
					
					let emails = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToEmails)
					guard let first = emails.first else {
						Conf.logger?.error("Cannot remove all the emails of a gougle user (id is an email…).")
						throw PropertyChangeResult.Failure.unremovableProperty
					}
					let other = Array(emails.dropFirst())
					let changed = (primaryEmail != first && aliases != other)
					primaryEmail = first
					aliases = other
					return changed ? .successChanged : .successUnchanged
					
				} catch {
					return .anyFailure(error)
				}
				
			case passwordProperty:
				do {
					if let newValue {
						let newPass = try Converters.convertPropertyValue(newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
						let hash = Insecure.SHA1.hash(data: Data(newPass.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
						let changed = (password != hash || passwordHashFunction != .sha1 || changePasswordAtNextLogin != false)
						changePasswordAtNextLogin = false
						passwordHashFunction = .sha1
						password = hash
						return changed ? .successChanged : .successUnchanged
						
					} else {
						let changed = (password != nil || passwordHashFunction != nil || changePasswordAtNextLogin != nil)
						password = nil
						passwordHashFunction = nil
						changePasswordAtNextLogin = nil
						return changed ? .successChanged : .successUnchanged
					}
					
				} catch {
					return .anyFailure(error)
				}
				
			default:
				return .failure(.unsupportedProperty)
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
			/* Other. */
			UserProperty("primaryEmail"): [.primaryEmail],
			.init(rawValue: "google/password"): [.password, .passwordHashFunction, .changePasswordAtNextLogin],
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
		/* Retrieving the password is not possible, of course. */
		return (keys.subtracting([.password]) + [.primaryEmail, .id, .kind]).map{ $0.stringValue }.joined(separator: ",")
	}
	
}
