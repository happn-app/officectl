/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async



public protocol DirectoryService {
	
	associatedtype UserType : Hashable
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: UserType) throws -> Action<UserType, String, Void>
	
	func existingUserId(from email: Email) -> Future<UserType?>
	func existingUserId<T : DirectoryService>(from user: T.UserType, in service: T) -> Future<UserType?>
	
}
