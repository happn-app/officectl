/*
 * OfficeKitUser.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Email
@preconcurrency import GenericJSON
import OfficeKit2



public struct OfficeKitUser : Codable, Sendable {
	
	public var id: String
	public var persistentID: String?
	
	public var isSuspended: Bool?
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var emails: [Email]?
	
	public var nonStandardProperties: [String: JSON]
	
	public var opaqueUserInfo: Data?
	
	public init(id: String, persistentID: String? = nil, underlyingUser: any User, nonStandardProperties: [String: JSON], opaqueUserInfo: Data?) {
		self.id = id
		self.persistentID = persistentID
		
		self.isSuspended = underlyingUser.oU_isSuspended
		self.firstName = underlyingUser.oU_firstName
		self.lastName = underlyingUser.oU_lastName
		self.nickname = underlyingUser.oU_nickname
		self.emails = underlyingUser.oU_emails
		
		self.nonStandardProperties = nonStandardProperties
		
		self.opaqueUserInfo = opaqueUserInfo
	}
	
}
