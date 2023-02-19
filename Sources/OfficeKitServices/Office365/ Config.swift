/*
 *  Config.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Logging



public enum Office365OfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.office365")
	
}

typealias Conf = Office365OfficeConfig
