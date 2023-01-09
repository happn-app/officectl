/*
 * ExistingUserFromPersistentIDRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct ExistingUserFromPersistentIDRequest : Codable, Sendable {
	
	public var userPersistentID: String
	public var propertiesToFetch: Set<UserProperty>?
	
}
