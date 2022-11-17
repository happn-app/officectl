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
	
	public var oU_id: Email {login}
	public var oU_persistentID: String? {id}
	
	public var oU_firstName: String? {firstName}
	public var oU_lastName: String? {lastName}
	public var oU_nickname: String? {nickname}
	
	public var oU_emails: [Email]? {[login]}
	
	public var oU_password: String? {password}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Any? {
		switch UserProperty(rawValue: property) {
			case .gender:    return gender
			case .birthdate: return birthDate
			default: return nil
		}
	}
	
}
