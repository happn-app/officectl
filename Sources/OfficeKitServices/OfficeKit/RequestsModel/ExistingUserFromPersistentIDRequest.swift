/*
 * ExistingUserFromPersistentIDRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct ExistingUserFromPersistentIDRequest : Codable, Sendable {
	
	var userPersistentID: String
	var propertiesToFetch: Set<UserProperty>?
	
}
