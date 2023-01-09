/*
 * ExistingUserFromIDRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct ExistingUserFromIDRequest : Codable, Sendable {
	
	var userID: String
	var propertiesToFetch: Set<UserProperty>?
	
}
