/*
 * DeleteUserRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit



public struct DeleteUserRequest : Codable, Sendable {
	
	public var user: OfficeKitUser
	
}
