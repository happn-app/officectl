/*
 * OfficeKitServices.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/17.
 */

import Foundation

import OfficeKit



struct OfficeKitServices : Sendable {
	
	static var providers = [String: OfficeService.Type]()
	
	var authService: (any AuthenticatorService)?
	var allServices = [String: any OfficeService]()
	
	var userServices: [any UserService] {
		return allServices.compactMap{ $0.value as? any UserService }
	}
	
	func hashableUserServices(matching serviceIDs: String?) -> Set<HashableUserService> {
		let serviceIDs = serviceIDs.flatMap{ Set($0.split(separator: ",").map(String.init)) }
		return Set(userServices.filter{ service in serviceIDs?.contains(service.id) ?? true }.map(HashableUserService.init))
	}
	
}
