/*
 * ExistingUserFromIDRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeModelCore

import OfficeKit



public struct ExistingUserFromIDRequest : Codable, Sendable {
	
	public var userID: TaggedID
	public var propertiesToFetch: Set<UserProperty>?
	
}
