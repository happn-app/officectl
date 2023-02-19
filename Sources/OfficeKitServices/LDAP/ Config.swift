/*
 *  Config.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import Logging



public enum LDAPOfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.ldap")
	
}

typealias Conf = LDAPOfficeConfig
