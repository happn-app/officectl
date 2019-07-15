/*
 * OpenDirectoryService+Utils.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import Async
import GenericJSON
import OfficeKit
import Service



extension OpenDirectoryService {
	
	func logicalUser(fromJSONUserId jsonUserId: JSON, on container: Container) throws -> ODRecordOKWrapper? {
		guard let userId = GenericDirectoryUserId(rawValue: jsonUserId) else {
			throw InvalidArgumentError(message: "Cannot convert JSON to GenericDirectoryUserId")
		}
		
		switch userId {
		case .native(let nativeIdJSON):
			guard let nativeIdStr = nativeIdJSON.stringValue, let nativeId = try? LDAPDistinguishedName(string: nativeIdStr) else {
				throw InvalidArgumentError(message: "Cannot convert given native id to dn")
			}
			return ODRecordOKWrapper(id: nativeId, emails: [])
			
		case .proxy(serviceId: let serviceId, user: let userIdJSON):
			switch serviceId {
			case "email":
				guard let emailStr = userIdJSON.stringValue, let email = Email(string: emailStr) else {
					throw InvalidArgumentError(message: "Cannot convert given native id to email")
				}
				return try logicalUser(fromEmail: email, hints: [:])
				
			default:
				throw InvalidArgumentError(message: "Unknown service id \(serviceId) to convert user id from")
			}
		}
	}
	
	func existingUser(fromJSONUserId jsonUserId: JSON, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		guard let userId = GenericDirectoryUserId(rawValue: jsonUserId) else {
			throw InvalidArgumentError(message: "Cannot convert JSON to GenericDirectoryUserId")
		}
		
		switch userId {
		case .native(let nativeIdJSON):
			guard let nativeIdStr = nativeIdJSON.stringValue, let nativeId = try? LDAPDistinguishedName(string: nativeIdStr) else {
				throw InvalidArgumentError(message: "Cannot convert given native id to dn")
			}
			return try existingUser(fromUserId: nativeId, propertiesToFetch: propertiesToFetch, on: container)
			
		case .proxy(serviceId: let serviceId, user: let userIdJSON):
			switch serviceId {
			case "email":
				guard let emailStr = userIdJSON.stringValue, let email = Email(string: emailStr) else {
					throw InvalidArgumentError(message: "Cannot convert given native id to email")
				}
				return try existingUser(fromEmail: email, propertiesToFetch: propertiesToFetch, on: container)
				
			default:
				throw InvalidArgumentError(message: "Unknown service id \(serviceId) to convert user id from")
			}
		}
	}
	
}
