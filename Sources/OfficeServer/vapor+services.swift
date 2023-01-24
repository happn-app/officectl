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
