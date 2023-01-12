/*
 * ExistingUserFromPersistentIDRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeModelCore

import OfficeKit



public struct ExistingUserFromPersistentIDRequest : Codable, Sendable {
	
	public var userPersistentID: TaggedID
	public var propertiesToFetch: Set<UserProperty>?
	
}
