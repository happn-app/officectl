/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async



public protocol DirectoryService {
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: TaggedId) throws -> some Action<Hashable, String, Void>
	
	func existingUserId(from email: Email) -> some Future<Hashable?>
	func existingUserId(from userId: TaggedId, in service: DirectoryService) -> some Future<Hashable?>
	
}
