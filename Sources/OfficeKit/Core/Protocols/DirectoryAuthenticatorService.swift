/*
 * DirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Async



public protocol DirectoryAuthenticatorService {
	
	associatedtype UserIdType : Hashable
	associatedtype AuthenticationChallenge
	
	func authenticate(user: UserIdType, challenge: AuthenticationChallenge) -> Future<Bool>
	func isUserAdmin(_ user: UserIdType) -> Future<Bool>
	
}
