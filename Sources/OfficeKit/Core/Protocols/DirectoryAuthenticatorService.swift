/*
 * DirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Async
import Service



public protocol DirectoryAuthenticatorService : DirectoryService {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(userId: UserType.IdType, challenge: AuthenticationChallenge, on container: Container) throws -> Future<Bool>
	func validateAdminStatus(userId: UserType.IdType, on container: Container) throws -> Future<Bool>
	
}
