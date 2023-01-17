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
	
}
