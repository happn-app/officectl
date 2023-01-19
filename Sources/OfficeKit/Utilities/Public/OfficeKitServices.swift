/*
 * OfficeKitServices.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/17.
 */

import Foundation



public struct OfficeKitServices : Sendable {
	
	public static var providers = [String: OfficeService.Type]()
	
	public var authService: (any AuthenticatorService)?
	public var allServices = [String: any OfficeService]()
	
	public init(authService: (any AuthenticatorService)? = nil, allServices: [String : any OfficeService] = [:]) {
		self.authService = authService
		self.allServices = allServices
	}
	
	public var userServices: [any UserService] {
		return allServices.compactMap{ $0.value as? any UserService }
	}
	
	public func hashableUserServices(matching serviceIDs: String?) -> Set<HashableUserService> {
		let serviceIDs = serviceIDs.flatMap{ Set($0.split(separator: ",").map(String.init)) }
		return Set(userServices.filter{ service in serviceIDs?.contains(service.id) ?? true }.map(HashableUserService.init))
	}
	
}
