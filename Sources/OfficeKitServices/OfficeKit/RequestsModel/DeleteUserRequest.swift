/*
 * DeleteUserRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct DeleteUserRequest : Codable, Sendable {
	
	var user: OfficeKitUser
	
}
