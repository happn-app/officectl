/*
 * HappnUser+OfficeModel.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/17.
 */

import Foundation

import CommonOfficePropertiesFromHappn
import Email
import OfficeKit2



extension HappnUser : User {
	
	public init(oU_id userID: Email) {
		self.login = userID
	}
	
	public var oU_id: Email {login}
	public var oU_persistentID: String? {id}
	
	public var oU_isSuspended: Bool? {status.flatMap{ $0 == .deactivated || $0 == .banned }}
	
	public var oU_firstName: String? {firstName}
	public var oU_lastName: String? {lastName}
	public var oU_nickname: String? {nickname}
	
	public var oU_emails: [Email]? {[login]}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch UserProperty(rawValue: property) {
			case .gender:    return gender
			case .birthdate: return birthDate
			default: return nil
		}
	}
	
	public mutating func oU_setValue(_ newValue: Sendable?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool {
		switch property {
			case .id, UserProperty("login"):
				guard allowIDChange else {return false}
				Conf.logger?.error("Changing the id of a happn user is not supported by the happn API.")
				return false
				
#warning("TODO")
//			case .firstName: return HappnUser.setValueIfNeeded(newValue, in: &firstName)
//			case .lastName:  return HappnUser.setValueIfNeeded(newValue, in: &lastName)
//			case .nickname:  return HappnUser.setValueIfNeeded(newValue, in: &nickname)
//			case .gender:    return HappnUser.setValueIfNeeded(newValue, in: &gender)
//			case .birthdate: return HappnUser.setValueIfNeeded(newValue, in: &birthDate, converter: { HappnBirthDateWrapper.birthDateFormatter.date(from: $0) })
//			case .password:  return HappnUser.setValueIfNeeded(newValue, in: &password)
			default:         return false
		}
	}

	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [HappnUser.CodingKeys]] {
		[
			.id: [.login],
			.persistentID: [.id],
			.isSuspended: [.status],
			.firstName: [.firstName],
			.lastName: [.lastName],
			.nickname: [.nickname],
			.emails: [.login],
			.password: [.password],
			.gender: [.gender],
			.birthdate: [._birthDate]
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<HappnUser.CodingKeys> {
		let properties = properties ?? Set(UserProperty.standardProperties + [.gender, .birthdate])
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
