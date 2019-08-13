/*
 * OpenDirectoryService+Utils.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import Async
import GenericJSON
import OfficeKit
import Service



extension OpenDirectoryService {
	
	func logicalUser(fromGenericDirectoryUser genericDirectoryUser: GenericDirectoryUser, on container: Container) throws -> ODRecordOKWrapper {
		var res = try logicalUser(fromGenericDirectoryUserId: genericDirectoryUser.userId, on: container)
		if let firstName = genericDirectoryUser.firstName.value {res.firstName = .set(firstName)}
		if let lastName = genericDirectoryUser.lastName.value {res.lastName = .set(lastName)}
		if let emails = genericDirectoryUser.emails.value {res.emails = .set(emails)}
		return res
	}
	
	func logicalUser(fromJSONUserId jsonUserId: JSON, on container: Container) throws -> ODRecordOKWrapper {
		guard let userId = GenericDirectoryUserId(rawValue: jsonUserId) else {
			throw InvalidArgumentError(message: "Cannot convert JSON to GenericDirectoryUserId")
		}
		return try logicalUser(fromGenericDirectoryUserId: userId, on: container)
	}
	
	func logicalUser(fromGenericDirectoryUserId userId: GenericDirectoryUserId, on container: Container) throws -> ODRecordOKWrapper {
		switch userId {
		case .native(let nativeIdJSON):
			guard let nativeIdStr = nativeIdJSON.stringValue, let nativeId = try? LDAPDistinguishedName(string: nativeIdStr) else {
				throw InvalidArgumentError(message: "Cannot convert given native id to dn")
			}
			return ODRecordOKWrapper(id: nativeId, emails: [])
			
		case .proxy(serviceId: let serviceId, userId: let proxyUserIdStr, user: _):
			switch serviceId {
			case "email", "ggl":
				guard let email = Email(string: proxyUserIdStr) else {
					throw InvalidArgumentError(message: "Cannot convert proxy user id to email: \(proxyUserIdStr)")
				}
				return try logicalUser(fromEmail: email)
				
			default:
				throw InvalidArgumentError(message: "Unknown service id \(serviceId) to convert user id to retrieve logical user")
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
			
		case .proxy(serviceId: let serviceId, userId: let proxyUserIdStr, user: _):
			switch serviceId {
			case "email", "ggl":
				guard let email = Email(string: proxyUserIdStr) else {
					throw InvalidArgumentError(message: "Cannot convert proxy user id to email: \(proxyUserIdStr)")
				}
				return try existingUser(fromEmail: email, propertiesToFetch: propertiesToFetch, on: container)
				
			default:
				throw InvalidArgumentError(message: "Unknown service id \(serviceId) to convert user id to retrieve existing user")
			}
		}
	}
	
}
