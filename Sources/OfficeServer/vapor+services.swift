/*
 * vapor+services.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import JWT
import Vapor

import OfficeKit
import ServiceKit



public extension Application {
	
	var jwtKey: JWKIdentifier? {
		get {storage[JWTKeyKey.self]}
		set {storage[JWTKeyKey.self] = newValue}
	}
	
	private struct JWTKeyKey: StorageKey {
		typealias Value = JWKIdentifier
	}
	
}


public extension Application {
	
	var authService: (any AuthenticatorService)? {
		get {storage[AuthServiceKey.self]}
		set {storage[AuthServiceKey.self] = newValue}
	}
	
	private struct AuthServiceKey: StorageKey {
		typealias Value = any AuthenticatorService
	}
	
	var officeKitServices: OfficeKitServices! {
		get {storage[OfficeKitServicesKey.self]}
		set {storage[OfficeKitServicesKey.self] = newValue}
	}
	
	private struct OfficeKitServicesKey: StorageKey {
		typealias Value = OfficeKitServices
	}
	
}



extension Application {
	
	var services: Services {
		if let existing = storage[ServicesKey.self] {
			return existing
		} else {
			var new = Services()
			new.register{ self.logger }
			storage[ServicesKey.self] = new
			return new
		}
	}
	
	private struct ServicesKey: StorageKey {
		typealias Value = Services
	}
	
}


extension Request {
	
	var services: Services {
		var ret = Services(duplicating: application.services)
		ret.register{ self.logger }
		return ret
	}
	
}
