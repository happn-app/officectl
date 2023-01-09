/*
 * ListAllUsersRequest.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OfficeKit2



public struct ListAllUsersRequest : Codable, Sendable {
	
	var includeSuspended: Bool
	var propertiesToFetch: Set<UserProperty>?
	
}
