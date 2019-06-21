/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async



public protocol OfficeKitService {
	
	static var id: String {get}
	
	var serviceId: String {get}
	var serviceName: String {get}
	
}

public protocol DirectoryService : OfficeKitService {
	
	associatedtype UserIdType : Hashable
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: UserIdType) throws -> Action<UserIdType, String, Void>
	
	func existingUserId<T: DirectoryService>(from userId: T.UserIdType, in service: T) -> Future<UserIdType?>
	
}

public protocol DirectoryServiceAuthenticator : DirectoryService {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(user: UserIdType, challenge: AuthenticationChallenge) -> Future<Bool>
	func isAdmin(_ user: UserIdType) -> Future<Bool>
	
}
