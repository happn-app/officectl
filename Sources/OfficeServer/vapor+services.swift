/*
 * vapor+services.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import JWT
import Vapor



public extension Application {
	
	var jwtKey: JWKIdentifier? {
		get {storage[JWTKeyKey.self]}
		set {storage[JWTKeyKey.self] = newValue}
	}
	
	private struct JWTKeyKey: StorageKey {
		typealias Value = JWKIdentifier
	}
	
}
