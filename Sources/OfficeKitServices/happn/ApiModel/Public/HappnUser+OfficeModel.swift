/*
 * HappnUser+OfficeModel.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/17.
 */

import Foundation

import Email

import CommonOfficePropertiesFromHappn
import OfficeKit



extension HappnUser : User {
	
	public init(oU_id userID: HappnUserID) {
		self.login = userID
	}
	
	/* Note about the ID: It is NOT a primary key!
	 * It is _technically_ possible that two admins from happn share the same key: `nil`.
	 * In practice this does not happ(e)n, but it could. */
	public var oU_id: HappnUserID {login}
	public var oU_persistentID: String? {id}
	
	public var oU_isSuspended: Bool? {status.flatMap{ $0 == .deactivated || $0 == .banned }}
	
	public var oU_firstName: String? {firstName}
	public var oU_lastName: String? {lastName}
	public var oU_nickname: String? {nickname}
	
	public var oU_emails: [Email]? {login.email.flatMap{ [$0] }}
	
	public var oU_nonStandardProperties: Set<String> {
		return [UserProperty.gender.rawValue, UserProperty.birthdate.rawValue]
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch UserProperty(rawValue: property) {
			case .gender:    return gender
			case .birthdate: return birthDate
			default: return nil
		}
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		let passwdProp = UserProperty(rawValue: HappnService.providerID + "/password")
		switch property {
			case .id, .persistentID, .emails:
				Conf.logger?.error("Changing the id (email) or persistent id of a happn user is not supported by the happn API.")
				return .failure(.readOnlyProperty)
				
			case .firstName: return Self.setOptionalProperty(&firstName, to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .lastName:  return Self.setOptionalProperty(&lastName,  to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .nickname:  return Self.setOptionalProperty(&nickname,  to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
			case .gender:    return Self.setOptionalProperty(&gender,    to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToGender)
			case .birthdate: return Self.setOptionalProperty(&birthDate, to: newValue, allowTypeConversion: convert, converter: Converters.objectToDateConverter{ HappnBirthDateWrapper.birthDateFormatter.date(from: $0) })
			case passwdProp: return Self.setOptionalProperty(&password,  to: newValue, allowTypeConversion: convert, converter: Converters.convertObjectToString)
				
			case .isSuspended:
				Conf.logger?.error("Suspending a user this way is not supported yet.")
				fallthrough
			default:
				return .failure(.unsupportedProperty)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [HappnUser.CodingKeys]] {
		[
			/* Standard. */
			.id: [.login, .firstName/*to see if the user exists*/, .isAdmin/*for info; good to have*/],
			.persistentID: [.id],
			.isSuspended: [.status],
			.emails: [.login],
			.firstName: [.firstName],
			.lastName: [.lastName],
			.nickname: [.nickname],
			/* Other. */
			.gender: [.gender],
			.birthdate: [._birthDate],
			.init(rawValue: HappnService.providerID + "/password"): [.password],
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<HappnUser.CodingKeys> {
		let properties = (properties ?? Set(UserProperty.standardProperties + [.gender, .birthdate])).union([.id])
		let keys = properties
			.compactMap{ propertyToKeys[$0] }
			.flatMap{ $0 }
		return Set(keys)
	}
	
	internal static func validFieldsParameter(from keys: Set<CodingKeys>) -> String {
		/* Retrieving the password is not possible, of course.
		 * The login, id and type are mandatory for the happn service to work properly (type not really, but whatever). */
		return (keys.subtracting([.password]) + [.login, .id, .type]).map{ $0.stringValue }.joined(separator: ",")
	}
	
}
