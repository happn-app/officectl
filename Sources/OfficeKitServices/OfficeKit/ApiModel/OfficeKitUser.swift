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
	
	public var underlyingUserAsJSON: JSON
	
	public init(id: String, persistentID: String? = nil, underlyingUserAndService: any UserAndService) throws {
		self.id = id
		self.persistentID = persistentID
		self.isSuspended = underlyingUserAndService.user.oU_isSuspended
		self.firstName = underlyingUserAndService.user.oU_firstName
		self.lastName = underlyingUserAndService.user.oU_lastName
		self.nickname = underlyingUserAndService.user.oU_nickname
		self.emails = underlyingUserAndService.user.oU_emails
		self.underlyingUserAsJSON = try underlyingUserAndService.userAsJSON()
	}
	
}
