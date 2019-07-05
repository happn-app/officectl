/*
 * DirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation

import Async



public protocol DirectoryAuthenticatorService : DirectoryService {
	
	associatedtype AuthenticationChallenge
	
	func authenticate(userId: UserType.IdType, challenge: AuthenticationChallenge) -> Future<Bool>
	func isUserIdOfAnAdmin(_ userId: UserType.IdType) -> Future<Bool>
	
}
