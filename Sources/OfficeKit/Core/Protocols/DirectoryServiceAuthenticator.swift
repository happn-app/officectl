/*
 * DirectoryServiceAuthenticator.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Async



public protocol DirectoryServiceAuthenticator : DirectoryService {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(user: UserIdType, challenge: AuthenticationChallenge) -> Future<Bool>
	func isAdmin(_ user: UserIdType) -> Future<Bool>
	
}
