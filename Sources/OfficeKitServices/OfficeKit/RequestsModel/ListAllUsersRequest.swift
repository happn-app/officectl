/*
 * ListAllUsersRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit



public struct ListAllUsersRequest : Codable, Sendable {
	
	public var includeSuspended: Bool
	public var propertiesToFetch: Set<UserProperty>?
	
}
