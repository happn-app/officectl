/*
 * AuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/21.
 */

import Foundation

import ServiceKit



public typealias HashableAuthenticatorService = DeportedHashability<any AuthenticatorService>

public protocol AuthenticatorService<UserType, AuthenticationChallenge> : OfficeService {
	
	associatedtype UserType : User
	associatedtype AuthenticationChallenge
	
	func authenticate(with challenge: AuthenticationChallenge, using services: Services) async throws -> UserType.IDType
	
}
