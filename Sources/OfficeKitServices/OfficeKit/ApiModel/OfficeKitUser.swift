/*
 * OfficeKitUser.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Email
@preconcurrency import GenericJSON
import OfficeModelCore

import OfficeKit2



public struct OfficeKitUser : Codable, Sendable {
	
	public var id: TaggedID
	public var persistentID: TaggedID?
	
	public var isSuspended: Bool?
	
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
	public var emails: [Email]?
	
	/** Must contain all the non-standard properties contained in the destination service’s user, encoded as JSON. */
	public var nonStandardProperties: [String: JSON]
	
	/**
	 Used by destination service internally to avoid re-fetching users from their upstream service if it can be avoided.
	 Can be left `nil`. */
	public var opaqueUserInfo: Data?
	
	/**
	 Init an OfficeKit user.
	 The standard properties are filled automatically from the underlying user. */
	public init(underlyingUser: any UserAndService, nonStandardProperties: [String: JSON], opaqueUserInfo: Data?) {
		self.id = underlyingUser.taggedID
		self.persistentID = underlyingUser.taggedPersistentID
		self.isSuspended = underlyingUser.user.oU_isSuspended
		self.firstName = underlyingUser.user.oU_firstName
		self.lastName = underlyingUser.user.oU_lastName
		self.nickname = underlyingUser.user.oU_nickname
		self.emails = underlyingUser.user.oU_emails
		
		self.nonStandardProperties = nonStandardProperties
		self.opaqueUserInfo = opaqueUserInfo
	}
	
}
