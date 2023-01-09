/*
 * UpdateUserRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct UpdateUserRequest : Codable, Sendable {
	
	public var user: OfficeKitUser
	public var propertiesToUpdate: Set<UserProperty>
	
}
