/*
 * AuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/21.
 */

import Foundation



public typealias HashableAuthenticatorService = DeportedHashability<any AuthenticatorService>

public protocol AuthenticatorService<AuthenticatedUserType, AuthenticationChallenge> : OfficeService {
	
	associatedtype AuthenticatedUserType : User
	associatedtype AuthenticationChallenge
	
	func authenticate(with challenge: AuthenticationChallenge) async throws -> AuthenticatedUserType.UserIDType
	
}


public extension Dictionary where Key == HashableAuthenticatorService {
	
	subscript(_ service: any AuthenticatorService) -> Value? {
		get {self[.init(value: service, valueID: service.id)]}
		set {self[.init(value: service, valueID: service.id)] = newValue}
	}
	
}
