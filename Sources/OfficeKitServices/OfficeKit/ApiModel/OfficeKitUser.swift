/*
 * OfficeKitUser.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Email
@preconcurrency import GenericJSON



public struct OfficeKitUser : Codable, Sendable {
	
	public var id: String
	public var persistentID: String?
	
	public var isSuspended: Bool?
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var emails: [Email]?
	
	public var nonStandardProperties = [String: JSON]()
	
}
