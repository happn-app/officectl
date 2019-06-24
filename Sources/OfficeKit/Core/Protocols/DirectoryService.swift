/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async



public protocol DirectoryService : OfficeKitService {
	
	associatedtype UserIdType : Hashable
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: UserIdType) throws -> Action<UserIdType, String, Void>
	
	func existingUserId(from email: Email) -> Future<UserIdType?>
	func existingUserId<T: DirectoryService>(from userId: T.UserIdType, in service: T) -> Future<UserIdType?>
	
}
