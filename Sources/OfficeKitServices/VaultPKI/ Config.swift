/*
 *  Config.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Logging



public enum VaultPKIOfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.vault-pki")
	
}

typealias Conf = VaultPKIOfficeConfig
