/*
 * UpdateUserRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct UpdateUserRequest : Codable, Sendable {
	
	var user: OfficeKitUser
	var propertiesToUpdate: Set<UserProperty>
	
}
